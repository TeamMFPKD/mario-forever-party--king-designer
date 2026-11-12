extends Node
class_name AdventureManager

## 百人团模式的门面（autoload：Adventure）。
##
## 负责：关卡池、4 档、当前团、命数、样本记录。
## 联机的 pass/death 存在 .lvl 里；这里只写 adventure.ini 的单人数据。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

signal run_started
signal run_changed
signal run_finished(summary: Dictionary)
## 「暂停是否被禁止」发生变化（已过关 / 过关转场播放中），暂停按钮据此切换 Disabled。
signal pause_blocked_changed

const DEFAULT_RUN_LENGTH: int = 10
const RUN_LENGTH_MIN: int = 5
const RUN_LENGTH_MAX: int = 50
const MIN_POOL: int = 5
const FINITE_LIVES_FACTOR: int = 2
const ENDLESS_LIVES: int = 30
const LIVES_CAP: int = 100
const LIFE_BONUS_EVERY: int = 2

const STAGE_SCENE: String = "res://room/adventure_stage.tscn"
const PLAY_SCENE: String = "res://room/adventure_play.tscn"
const RESULT_SCENE: String = "res://room/adventure_result.tscn"

var store: AdventureStore
var pool: Array[AdventureLevelStat] = []
var pool_source: String = ""
var current_run: Dictionary = {}
var last_summary: Dictionary = {}
var last_error: String = ""

var current_key: String = ""
var resume_available: bool = false
var _tier_info: Dictionary = {}

var _transition_layer: CanvasLayer
var _transition_dim: ColorRect
var _transition_panel: Panel
var _transition_label: Label

## 关卡视口内的过关转场（room/adventure_play.tscn 注册，随场景销毁自动失效）
var _clear_transition: CanvasLayer
## 过关转场是否正在播放：防止加载期间玩家碰到下一关终点又触发一次转场。
var _pass_transition_busy: bool = false
## 本次关卡是否已经过关（碰到终点 → 下一关加载完成）。期间禁止暂停。
var _level_passed_busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	store = AdventureStore.new()
	store.load()
	_build_transition_ui()
	_check_resume()


# ---------------------------------------------------------------------------
# 设置 / 池 / 分档
# ---------------------------------------------------------------------------

func get_settings() -> Dictionary:
	return {
		"pool_source": str(store.get_setting("pool_source", "all")),
		"tier": int(store.get_setting("tier", 0)),
		"mode": str(store.get_setting("mode", "finite")),
		"run_length": int(store.get_setting("run_length", DEFAULT_RUN_LENGTH)),
		"prefer_low_sample": bool(store.get_setting("prefer_low_sample", true)),
	}


func save_settings(settings: Dictionary) -> void:
	for key: String in ["pool_source", "tier", "mode", "run_length", "prefer_low_sample"]:
		if settings.has(key):
			store.set_setting(key, settings[key])


func load_pool(source: String) -> Array[AdventureLevelStat]:
	pool = AdventurePoolBuilder.build(store, source)
	pool_source = source
	_tier_info = AdventureTierCalculator.assign_tiers(pool)
	return pool


## 舞台线程加载完成后，在主线程把结果交给 Adventure。
func set_pool(stats: Array[AdventureLevelStat], source: String) -> void:
	pool = stats
	pool_source = source
	_tier_info = AdventureTierCalculator.assign_tiers(pool)


func apply_pool_meta(updates: Array) -> void:
	AdventurePoolBuilder.apply_updates(store, updates)


func get_pool() -> Array[AdventureLevelStat]:
	return pool


func playable_count() -> int:
	var count: int = 0
	for stat: AdventureLevelStat in pool:
		if stat.file_exists and not stat.excluded:
			count += 1
	return count


func get_tier_info() -> Dictionary:
	return _tier_info


func is_running() -> bool:
	return not current_run.is_empty() and bool(current_run.get("active", false))


func _check_resume() -> void:
	var saved: Dictionary = store.get_run()
	if saved.is_empty() or not bool(saved.get("active", false)):
		resume_available = false
		return
	var keys: Array = saved.get("level_keys", [])
	var index: int = int(saved.get("index", 0))
	resume_available = not keys.is_empty() and index >= 0 and index < keys.size()


func resume_run() -> bool:
	if not resume_available:
		return false
	var saved: Dictionary = store.get_run()
	if saved.is_empty() or not bool(saved.get("active", false)):
		resume_available = false
		return false
	var source: String = str(store.get_setting("pool_source", "all"))
	if pool_source != source or pool.is_empty():
		load_pool(source)
	current_run = saved
	current_key = ""
	resume_available = false
	_set_level_passed_busy(false)
	GameModeSingleton.set("game_mode", GameMode.GameModeType.ADVENTURE)
	run_started.emit()
	run_changed.emit()
	return true


func current_level_key() -> String:
	if not is_running():
		return ""
	var keys: Array = current_run.get("level_keys", [])
	var index: int = int(current_run.get("index", 0))
	if index < 0 or index >= keys.size():
		return ""
	return str(keys[index])


func current_level_path() -> String:
	return resolve_level_path(current_level_key())


## 当前关卡在本团里的序号（1 起）：过场动画的「第 N/M 关」和关卡串编号都用它。
## 跳过一关也会占掉一个序号，所以不能拿「通过数」cleared_count 当关号。
func current_level_number() -> int:
	if not is_running():
		return 0
	return maxi(1, int(current_run.get("index", 0)) + 1)


## 本团总关数；无尽团为 -1。
func current_total_levels() -> int:
	if not is_running():
		return -1
	return int(current_run.get("total_levels", -1))


## 本团已通过的关数（无尽团过场显示「已通过 N 关」用）。
func cleared_count() -> int:
	if not is_running():
		return 0
	return int(current_run.get("cleared_count", 0))


## 左侧关卡信息面板用：当前关卡在 adventure.ini 里的单人统计。
## 数值均为「这一关」的累计，不是本团的即时计数。
func current_level_stats() -> Dictionary:
	var empty: Dictionary = {
		"solo_attempt": 0,
		"solo_pass": 0,
		"solo_death": 0,
		"solo_skip": 0,
		"solo_skip_soft": 0,
	}
	if not is_running():
		return empty
	var key: String = current_level_key()
	if key.is_empty():
		return empty
	var saved: Dictionary = store.get_level_data(key)
	var stats: Dictionary = empty.duplicate()
	for field: String in stats.keys():
		stats[field] = int(saved.get(field, 0))
	return stats


func resolve_level_path(key: String) -> String:
	if key.is_empty():
		return ""
	var root_path: String = "user://" + key
	if FileAccess.file_exists(root_path):
		return root_path
	var liked_path: String = "user://liked courses/" + key
	if FileAccess.file_exists(liked_path):
		return liked_path
	return root_path


# ---------------------------------------------------------------------------
# 开始 / 推进
# ---------------------------------------------------------------------------

func start_run(settings: Dictionary) -> bool:
	last_error = ""
	var source: String = str(settings.get("pool_source", "all"))
	var mode: String = str(settings.get("mode", "finite"))
	var requested_tier: int = clampi(int(settings.get("tier", 0)), 0, 4)
	var run_length: int = clampi(
		int(settings.get("run_length", DEFAULT_RUN_LENGTH)),
		RUN_LENGTH_MIN,
		RUN_LENGTH_MAX
	)
	var prefer_low_sample: bool = bool(settings.get("prefer_low_sample", true))

	if pool_source == source and not pool.is_empty():
		_tier_info = AdventureTierCalculator.assign_tiers(pool)
	else:
		load_pool(source)
	if playable_count() < MIN_POOL:
		last_error = "可玩关卡不足（至少需要 %d 关）" % MIN_POOL
		return false

	var tier: int = requested_tier
	if tier > 0 and not bool(_tier_info.get("selectable", false)):
		tier = 0

	var run_seed: int = int(Time.get_unix_time_from_system()) ^ (randi() & 0xffff)
	var keys: Array[String] = []
	if mode == "endless":
		keys = AdventureRunPlanner.draw(pool, tier, 1, run_seed, prefer_low_sample)
	else:
		keys = AdventureRunPlanner.draw(pool, tier, run_length, run_seed, prefer_low_sample)
		run_length = maxi(1, keys.size())

	if keys.is_empty():
		last_error = "没有抽到可玩的关卡"
		return false

	var lives_total: int = ENDLESS_LIVES
	var total_levels: int = -1
	if mode == "finite":
		lives_total = run_length * FINITE_LIVES_FACTOR
		total_levels = run_length

	resume_available = false
	current_run = {
		"active": true,
		"id": _make_run_id(),
		"mode": mode,
		"seed": run_seed,
		"tier": tier,
		"active_tier": tier,
		"started_at": int(Time.get_unix_time_from_system()),
		"index": 0,
		"total_levels": total_levels,
		"lives_total": lives_total,
		"lives_left": lives_total,
		"lives_cap": LIVES_CAP,
		"cleared_count": 0,
		"skipped_count": 0,
		"skipped_soft": 0,
		"skipped_hard": 0,
		"cycle": 1,
		"cycle_played": [],
		"level_keys": keys,
		"level_fingerprints": _fingerprints_for(keys),
	}
	current_key = ""
	_set_level_passed_busy(false)
	store.set_run(current_run)
	GameModeSingleton.set("game_mode", GameMode.GameModeType.ADVENTURE)
	run_started.emit()
	run_changed.emit()
	return true


## load_level.gd 在关卡成功加载后调用。只在百人团模式记录。
func on_level_loaded(path: String) -> void:
	# 新关卡就绪：上一关的「已过关」状态作废。
	# 转场还没播完时仍由 _pass_transition_busy 挡住暂停，不会提前放开。
	_set_level_passed_busy(false)
	if not GameMode.is_adventure():
		return
	var key: String = path.get_file()
	if key.is_empty():
		return
	current_key = key
	store.record_attempt(key)
	_refresh_stat(key)
	if is_running():
		run_changed.emit()


## 只有百人团模式会记录；history play 的通过不算进百人团数据。
func on_level_passed() -> void:
	if not GameMode.is_adventure():
		return
	if current_key.is_empty():
		return
	store.record_pass(current_key)
	_refresh_stat(current_key)
	if not is_running():
		return

	var cleared: int = int(current_run.get("cleared_count", 0)) + 1
	current_run["cleared_count"] = cleared
	if cleared % LIFE_BONUS_EVERY == 0:
		var lives: int = mini(int(current_run.get("lives_left", 0)) + 1, LIVES_CAP)
		current_run["lives_left"] = lives
	store.set_run(current_run)
	advance()


## 只有百人团模式会记录；history play 的死亡不算进百人团数据。
func on_player_died() -> void:
	if not GameMode.is_adventure():
		return
	if current_key.is_empty():
		return
	store.record_death(current_key)
	_refresh_stat(current_key)
	if not is_running():
		return

	var lives: int = int(current_run.get("lives_left", 0)) - 1
	current_run["lives_left"] = lives
	if lives <= 0:
		finish_run("failed")
		return
	store.set_run(current_run)
	run_changed.emit()


func skip_current_level(hard: bool) -> void:
	if not is_running() or current_key.is_empty():
		return
	store.record_skip(current_key, not hard)
	if hard:
		store.set_excluded(current_key, true, "unsolvable")
		current_run["skipped_hard"] = int(current_run.get("skipped_hard", 0)) + 1
	else:
		current_run["skipped_soft"] = int(current_run.get("skipped_soft", 0)) + 1
	current_run["skipped_count"] = int(current_run.get("skipped_count", 0)) + 1

	var stat: AdventureLevelStat = _find_stat(current_key)
	if stat != null:
		stat.solo_skip += 1
		if hard:
			stat.excluded = true
			stat.exclude_reason = "unsolvable"
		else:
			stat.solo_skip_soft += 1

	# 定量团的最后一关被跳过时不能直接算通关：抽一关补上这个位置，
	# 玩家打完替补关卡才结算（否则跳一下就直接「走完了整条路线」）。
	if _is_finite_last_slot():
		if _replace_current_slot():
			store.set_run(current_run)
			run_changed.emit()
			return
		Log.w("Adventure", "最后一关被跳过且抽不到替补关卡，本团提前结束")
		finish_run("no_levels")
		return

	store.set_run(current_run)
	advance()


func abandon_run() -> void:
	if not is_running():
		return
	finish_run("abandoned")


## 中断 = 保存当前团进度并退出，不结算、不增加放弃次数。
func interrupt_run() -> void:
	if not is_running():
		return
	store.set_run(current_run)
	resume_available = true


# ---------------------------------------------------------------------------
# 推进内部
# ---------------------------------------------------------------------------

## 当前是否正停在定量团的最后一格。
func _is_finite_last_slot() -> bool:
	if str(current_run.get("mode", "finite")) != "finite":
		return false
	var total: int = int(current_run.get("total_levels", 0))
	return total > 0 and int(current_run.get("index", 0)) >= total - 1


## 用一关新的补给替换当前格：关数不变、序号不变，只是换一张地图接着打。
## 抽不到（池子里全玩过 / 全排除）时返回 false。
func _replace_current_slot() -> bool:
	var index: int = int(current_run.get("index", 0))
	var keys: Array = current_run.get("level_keys", [])
	if index < 0 or index >= keys.size():
		return false
	var replacement: String = _draw_replacement_key()
	if replacement.is_empty():
		return false

	keys[index] = replacement
	current_run["level_keys"] = keys
	var fingerprints: Array = current_run.get("level_fingerprints", [])
	while fingerprints.size() < keys.size():
		fingerprints.append("")
	fingerprints[index] = _fingerprint_for(replacement)
	current_run["level_fingerprints"] = fingerprints
	return true


## 从池子里抽一关本团还没出现过的关卡，沿用开团时的档位。
func _draw_replacement_key() -> String:
	AdventureTierCalculator.assign_tiers(pool)
	var used: Array[String] = []
	for entry: Variant in current_run.get("level_keys", []):
		used.append(str(entry))
	if not current_key.is_empty() and not used.has(current_key):
		used.append(current_key)

	var prefer_low_sample: bool = bool(store.get_setting("prefer_low_sample", true))
	var draw_seed: int = int(current_run.get("seed", 0)) + int(current_run.get("index", 0))
	var tier: int = int(current_run.get("tier", 0))
	var drawn: Array[String] = AdventureRunPlanner.draw(
		pool, tier, 1, draw_seed, prefer_low_sample, used
	)
	if drawn.is_empty() and tier > 0:
		# 本档抽空：退回随机抽取，至少把这一格补上。
		drawn = AdventureRunPlanner.draw(pool, 0, 1, draw_seed, prefer_low_sample, used)
	return "" if drawn.is_empty() else drawn[0]


func advance() -> void:
	if not is_running():
		return
	var mode: String = str(current_run.get("mode", "finite"))
	var keys: Array = current_run.get("level_keys", [])
	var index: int = int(current_run.get("index", 0)) + 1
	current_run["index"] = index

	if mode == "finite":
		var total: int = int(current_run.get("total_levels", 0))
		if index >= total:
			finish_run("completed")
			return
	else:
		var played: Array = current_run.get("cycle_played", [])
		if not current_key.is_empty() and not played.has(current_key):
			played.append(current_key)
		current_run["cycle_played"] = played
		var next_key: String = _next_endless_key()
		if next_key.is_empty():
			finish_run("no_levels")
			return
		keys.append(next_key)
		current_run["level_keys"] = keys
		var fingerprints: Array = current_run.get("level_fingerprints", [])
		fingerprints.append(_fingerprint_for(next_key))
		current_run["level_fingerprints"] = fingerprints

	store.set_run(current_run)
	run_changed.emit()


func _next_endless_key() -> String:
	var prefer_low_sample: bool = bool(store.get_setting("prefer_low_sample", true))
	var selected_tier: int = int(current_run.get("tier", 0))
	var active_tier: int = int(current_run.get("active_tier", selected_tier))
	var attempts: int = 0

	while attempts < 6:
		attempts += 1
		AdventureTierCalculator.assign_tiers(pool)
		var played: Array = current_run.get("cycle_played", [])
		var exclude_keys: Array[String] = []
		for entry: Variant in played:
			exclude_keys.append(str(entry))
		var draw_seed: int = int(current_run.get("seed", 0)) + int(current_run.get("index", 0))
		var drawn: Array[String] = AdventureRunPlanner.draw(
			pool, active_tier, 1, draw_seed, prefer_low_sample, exclude_keys
		)
		if not drawn.is_empty():
			current_run["active_tier"] = active_tier
			return drawn[0]

		# 当前档抽空：降档。
		if active_tier > 1:
			active_tier -= 1
			current_run["active_tier"] = active_tier
			Log.i("Adventure", ["当前档抽空，降为 ", active_tier, " 档"])
			continue

		# 1 档也抽空：所有关卡都玩过 → 新一轮。
		var played_all: Array = current_run.get("cycle_played", [])
		if not played_all.is_empty():
			current_run["cycle_played"] = []
			current_run["cycle"] = int(current_run.get("cycle", 1)) + 1
			active_tier = selected_tier
			current_run["active_tier"] = active_tier
			Log.i("Adventure", "所有关卡已玩过，开始新一轮")
			continue
		return ""

	return ""


func finish_run(result: String) -> void:
	if current_run.is_empty():
		return
	var summary: Dictionary = current_run.duplicate(true)
	summary["result"] = result
	summary["finished_at"] = int(Time.get_unix_time_from_system())
	last_summary = summary

	var mode: String = str(current_run.get("mode", "finite"))
	store.set_stat(
		"runs_finite" if mode == "finite" else "runs_endless",
		store.get_stat("runs_finite" if mode == "finite" else "runs_endless", 0) + 1
	)
	match result:
		"completed":
			store.set_stat("runs_completed", store.get_stat("runs_completed", 0) + 1)
		"failed":
			store.set_stat("runs_failed", store.get_stat("runs_failed", 0) + 1)
		"abandoned":
			store.set_stat("runs_abandoned", store.get_stat("runs_abandoned", 0) + 1)
	if mode == "endless":
		var cleared: int = int(current_run.get("cleared_count", 0))
		store.set_stat("endless_total_cleared", store.get_stat("endless_total_cleared", 0) + cleared)
		store.set_stat("endless_total_deaths", store.get_stat("endless_total_deaths", 0) + int(current_run.get("lives_total", 0)) - int(current_run.get("lives_left", 0)))
		if cleared > store.get_stat("best_endless_cleared", 0):
			store.set_stat("best_endless_cleared", cleared)
	store.save()

	current_run = {}
	current_key = ""
	resume_available = false
	store.clear_run()
	run_finished.emit(summary)


# ---------------------------------------------------------------------------
# 过渡动画
# ---------------------------------------------------------------------------

func _build_transition_ui() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.name = "AdventureTransition"
	_transition_layer.layer = 40
	_transition_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_transition_layer)

	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_transition_layer.add_child(root)

	_transition_dim = ColorRect.new()
	_transition_dim.color = Color(0, 0, 0, 0.38)
	_transition_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_transition_dim)

	_transition_panel = Panel.new()
	_transition_panel.anchor_left = 0.5
	_transition_panel.anchor_top = 0.5
	_transition_panel.anchor_right = 0.5
	_transition_panel.anchor_bottom = 0.5
	_transition_panel.offset_left = -110
	_transition_panel.offset_top = -65
	_transition_panel.offset_right = 110
	_transition_panel.offset_bottom = 65
	_transition_panel.pivot_offset = Vector2(110, 65)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.corner_radius_top_left = 65
	style.corner_radius_top_right = 65
	style.corner_radius_bottom_left = 65
	style.corner_radius_bottom_right = 65
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.12, 0.12, 0.16, 0.75)
	_transition_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_transition_panel)

	_transition_label = Label.new()
	_transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_transition_label.add_theme_font_size_override("font_size", 64)
	_transition_label.add_theme_color_override("font_color", Color("#1A1A1A"))
	_transition_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_panel.add_child(_transition_label)

	_transition_layer.visible = false


func register_clear_transition(node: CanvasLayer) -> void:
	_clear_transition = node


## 过关转场是否正在播放（加载下一关期间玩家不应该再次触发过关）。
func is_pass_transition_running() -> bool:
	return _pass_transition_busy


## 暂停是否被禁止：已过关或过关转场播放中。
## 暂停键与手机暂停按钮都以此为准，按钮同时置为 Disabled。
func is_pause_blocked() -> bool:
	return _level_passed_busy or _pass_transition_busy


## GoalGate 碰到终点时调用：从这一刻起禁止暂停，直到下一关加载完成。
func notify_level_passed() -> void:
	_set_level_passed_busy(true)


func _set_level_passed_busy(value: bool) -> void:
	if _level_passed_busy == value:
		return
	_level_passed_busy = value
	pause_blocked_changed.emit()


## 过关转场 + 下一关预热。
##
## 时序：
##   0.00s   在关卡视口里开始播转场（黄色块划入）
##   0.83s   播到一半：转场搬到主视口继续播；同时切到下一关场景并解析关卡
##   加载完   暂停整个关卡（转场是 PROCESS_MODE_ALWAYS，继续播）
##   1.66s   转场播完 → 解冻，玩家开始玩
##
## 转场搬到主视口之后旧场景才允许销毁，所以切场景不会打断转场。
func _play_pass_transition(next_scene: String, level_number: int = 0, total_levels: int = 0) -> void:
	if _pass_transition_busy:
		Log.w("Adventure", "过关转场尚未结束，忽略重复的过关请求")
		return
	_pass_transition_busy = true
	pause_blocked_changed.emit()
	await _run_pass_transition(next_scene, level_number, total_levels)
	_pass_transition_busy = false
	pause_blocked_changed.emit()


func _run_pass_transition(next_scene: String, level_number: int = 0, total_levels: int = 0) -> void:
	var transition: CanvasLayer = _clear_transition
	if not is_instance_valid(transition):
		return
	# 过场显示「刚通过的关卡序号」：按团进度 index 计算，跳过一关也不会串号；
	# 结算时 current_run 已被清空，只能用调用方在推进进度前传进来的快照。
	var number: int = level_number if level_number > 0 else int(current_run.get("cleared_count", 1))
	var total: int = total_levels if total_levels != 0 else int(current_run.get("total_levels", -1))

	# 跳到别的场景（例如结算页）：沿用旧的「播完再切」。
	if not next_scene.is_empty():
		transition.call("play", number, total)
		await _wait_transition_end(transition)
		GlobalTransition.change_scene_to_file(next_scene)
		return

	# 下一关没加载完之前不让转场划出，避免露出还没准备好的画面。
	if transition.has_method("set_slide_out_blocked"):
		transition.call("set_slide_out_blocked", true)
	transition.call("play", number, total)

	var detach_result: Dictionary = await _detach_and_load_next_level(transition)
	var detached: bool = bool(detach_result.get("detached", false))
	var advanced: bool = bool(detach_result.get("advanced", false))

	if is_instance_valid(transition) and transition.has_method("set_slide_out_blocked"):
		transition.call("set_slide_out_blocked", false)
	await _wait_transition_end(transition)

	if detached and is_instance_valid(transition):
		transition.call("release_from_screen")

	if advanced:
		# 下一关在加载完成时就已经冻结，转场播完直接解冻开始游戏。
		var scene: Node = get_tree().current_scene
		if scene != null:
			# 冻结期间玩家的暂停键有可能把暂停菜单打开，这里复位掉。
			var menu: Node = scene.find_child("AdventurePauseMenu", true, false)
			if is_instance_valid(menu) and menu.has_method("force_close"):
				menu.call("force_close")
		get_tree().paused = false
		Log.i("Adventure", "转场结束，开始游玩下一关")
		return

	# 预热失败：回退到旧的「过场结束后重载当前场景」。
	Log.w("Adventure", "下一关预热失败，回退到常规重载")
	GlobalTransition.reload_current_scene()


## 等转场播到一半 → 把转场搬到主视口 → 等马里奥落地静止 → 加载下一关。
## 返回 {"detached": 转场是否已搬走, "advanced": 下一关是否加载成功}。
func _detach_and_load_next_level(transition: CanvasLayer) -> Dictionary:
	var failed: Dictionary = {"detached": false, "advanced": false}
	if not is_instance_valid(transition) or not transition.has_signal("halfway"):
		return failed

	# 半程：把转场搬到主视口（纯节点搬运，不卡）。
	if not await _wait_transition_signal(transition, "halfway", 3.0):
		return failed
	await get_tree().process_frame
	if not is_instance_valid(transition):
		return failed
	if not bool(transition.call("detach_from_level_view", _game_view_rect())):
		return failed

	# 马里奥落地、画面进入静止 hold 的那一刻再加载下一关：
	# 加载卡顿会被静止画面吃掉，玩家察觉不到。
	# 加载没完之前 _slide_out_blocked 会挡住划出。
	if not await _wait_transition_signal(transition, "jump_finished", 3.0):
		return failed
	await get_tree().process_frame

	var next_scene: Node = await _load_next_play_scene(transition)
	return {"detached": true, "advanced": is_instance_valid(next_scene)}


## 等转场脚本的某个信号。转场不在 CanvasLayer 的静态类型里，用连接 + 轮询。
func _wait_transition_signal(transition: CanvasLayer, signal_name: String, timeout: float) -> bool:
	if not is_instance_valid(transition) or not transition.has_signal(signal_name):
		return false
	var state: Dictionary = {"reached": false}
	transition.connect(
		signal_name,
		func() -> void: state["reached"] = true,
		CONNECT_ONE_SHOT
	)
	var waited: float = 0.0
	while not bool(state["reached"]) and is_instance_valid(transition) and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return bool(state["reached"])


## 关卡画面（SubViewportContainer）在主视口里的全局矩形。
func _game_view_rect() -> Rect2:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var container: Control = scene.get_node_or_null(
			"GameRoomSize/SubViewportContainer"
		) as Control
		if container != null:
			return container.get_global_rect()
	return Rect2(Vector2(320.0, 32.0), Vector2(1280.0, 928.0))


## 切到下一关游玩场景，等关卡数据完全写进场景后跑 1 物理帧，再暂停（冻结）。
##
## 不用 change_scene_to_packed：它在帧末才把新场景挂进树，那一帧新场景会画在转场上面，
## 而它的 SubViewport 第一帧还没渲染 —— 会看到关卡区域闪黑一下。
## 这里手动换：新场景先隐藏着挂进树 → 把转场插进它的关卡视口 → 同一帧内显示新场景、
## 设为当前场景、释放旧场景，整帧内两个场景都在，不会出现空档。
func _load_next_play_scene(transition: CanvasLayer) -> Node:
	var packed: PackedScene = load(PLAY_SCENE) as PackedScene
	if packed == null:
		Log.e("Adventure", ["下一关场景加载失败：", PLAY_SCENE])
		return null
	var instantiate_start: int = Time.get_ticks_msec()
	var next_scene: Node = packed.instantiate()
	var instantiate_cost: int = Time.get_ticks_msec() - instantiate_start
	if next_scene == null:
		return null
	var previous: Node = get_tree().current_scene

	var manager: LevelManager = next_scene.find_child("LevelManager", true, false) as LevelManager

	# 先隐藏 + 冻结，避免新场景在转场插好之前先画一帧。
	var canvas_item: CanvasItem = next_scene as CanvasItem
	if canvas_item != null:
		canvas_item.visible = false
	next_scene.process_mode = Node.PROCESS_MODE_DISABLED

	# 趁新场景还没入树，先把转场挂进它的关卡视口。
	# 这样新场景入树的那一帧转场已经在容器里、直接能画出来；
	# 如果等入树后再搬，CanvasItem 重新挂父节点要下一帧才生效，会闪一帧。
	# 容器尺寸固定为 1280×960（SubViewport 的像素尺寸）。
	if is_instance_valid(transition):
		var container: Control = next_scene.get_node_or_null(
			"GameRoomSize/SubViewportContainer"
		) as Control
		transition.call(
			"attach_to_game_view",
			container,
			Rect2(Vector2.ZERO, Vector2(1280.0, 960.0))
		)

	# 挂新场景之前先把旧场景从树上摘掉：
	# 否则新场景的 _ready 会从 level_camera / player 组里拿到旧场景的节点，
	# 旧场景帧末释放后这些缓存就变成 previously freed。
	# 同一帧内 remove + add，渲染帧末只有新场景，不会出现空档。
	if previous != null and previous != next_scene:
		var previous_parent: Node = previous.get_parent()
		if previous_parent != null:
			previous_parent.remove_child(previous)
		previous.queue_free()

	var add_start: int = Time.get_ticks_msec()
	get_tree().root.add_child(next_scene)
	var add_cost: int = Time.get_ticks_msec() - add_start
	Log.i("Adventure", ["换关耗时：instantiate=", instantiate_cost, "ms add_child=", add_cost, "ms"])
	get_tree().current_scene = next_scene

	# _ready 里可能新建 CanvasLayer（暂停按钮），一并隐藏。
	var hidden_layers: Array[CanvasLayer] = []
	for child: Node in next_scene.get_children():
		var layer: CanvasLayer = child as CanvasLayer
		if layer != null and layer.visible:
			layer.visible = false
			hidden_layers.append(layer)

	# 同一帧内显示新场景并冻结
	if canvas_item != null:
		canvas_item.visible = true
	for layer: CanvasLayer in hidden_layers:
		layer.visible = true
	next_scene.process_mode = Node.PROCESS_MODE_INHERIT
	# 加载期间先冻结，避免玩家/敌人在分帧加载时乱跑。
	get_tree().paused = true

	if manager == null:
		Log.e("Adventure", "新场景缺少 LevelManager")
		return null

	# 等关卡数据按帧写进场景（对象实例化分帧，见 ObjectMapLayer.load_object_data）。
	var waited: float = 0.0
	while not manager.is_level_data_ready and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not manager.is_level_data_ready:
		Log.e("Adventure", "下一关加载超时")
		return null

	# 加载结束后先跑 2 个物理帧，让玩家/物体完成物理初始化，再冻结。
	await settle_physics_frames(2)
	return next_scene


## 跳过 / 排除用：把下一关场景预加载好、挂进树并冻结，返回新场景节点。
##
## 旧场景会在内部销毁，所以调用方（暂停菜单）必须先把自己 reparent 到 root；
## 之后卡片后面就是新关卡本身，翻开卡片就能直接露出新关卡。
func preload_next_level_scene() -> Node:
	return await _load_next_play_scene(null)


## 等转场播完（visible 变 false）。转场可能已被搬到主视口，也可能还在关卡视口里。
func _wait_transition_end(transition: CanvasLayer) -> void:
	var waited: float = 0.0
	while is_instance_valid(transition) and transition.visible and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


## 冻结关卡前先让物理跑满 count 帧。
##
## 直接 paused = true 会把「算到一半」的那一帧定住：物理步刚推进、绘制还没跟上，
## 切场景时上一关容易残留一帧。先放满若干个物理帧再冻结，
## 冻住的画面和物理状态才是同一帧。
##
## 返回时关卡已冻结，调用方接着播转场 / 切场景即可。
func settle_physics_frames(count: int = 2) -> void:
	get_tree().paused = false
	var target: int = Engine.get_physics_frames() + maxi(count, 1)
	var guard: int = 0
	while Engine.get_physics_frames() < target and guard < 600:
		await get_tree().process_frame
		guard += 1
	get_tree().paused = true


## kind: pass / skip / finish；next_scene 为空时重载当前场景。
## 死亡不播专用符号动画，直接走全局淡出。
## level_number / total_levels 是过关前的进度快照（0 = 没传，按当前团状态兜底）。
func play_transition(
	kind: String,
	next_scene: String = "",
	level_number: int = 0,
	total_levels: int = 0
) -> void:
	# 过关转场进行中：忽略新的转场请求，否则会把加载期间的暂停解掉 / 跳过关卡。
	if _pass_transition_busy:
		Log.w("Adventure", "转场进行中，忽略新的转场请求")
		return

	# 结算：终点处已经冻结了 1 秒，保持冻结直接切结算页（结算页自己解冻）。
	# 同样不再 settle，避免过关后旧关卡多跑 2 帧才被重新冻住。
	if kind == "finish":
		get_tree().paused = true
		GlobalTransition.change_scene_to_file(RESULT_SCENE if next_scene.is_empty() else next_scene)
		return

	if kind == "death":
		get_tree().paused = false
		if next_scene.is_empty():
			GlobalTransition.reload_current_scene()
		else:
			GlobalTransition.change_scene_to_file(next_scene)
		return

	# 过关优先在关卡视口里播前端转场（只覆盖 640×480 的游戏画面）
	if kind == "pass" and is_instance_valid(_clear_transition):
		# GoalGate 已经冻结了 1 秒，画面和物理状态早就同步，这里不要再解冻「放满 2 个物理帧」：
		# 那会让过关后的旧关卡又多跑 1~2 帧才重新冻住（玩家、敌人、倒计时都跟着动一下）。
		# 直接保持暂停，整段过场里旧关卡都不推进（转场是 PROCESS_MODE_ALWAYS）。
		get_tree().paused = true
		await _play_pass_transition(next_scene, level_number, total_levels)
		return

	# 跳过：整个过场期间冻结关卡，切完场景由新场景解冻。
	get_tree().paused = true
	if _transition_layer == null:
		if next_scene.is_empty():
			GlobalTransition.reload_current_scene()
		else:
			GlobalTransition.change_scene_to_file(next_scene)
		return

	var symbol: String = "✓"
	var color: Color = Color("#2E9E5B")
	if kind == "skip":
		symbol = "→"
		color = Color("#D39B22")
	_transition_label.text = symbol
	_transition_label.add_theme_color_override("font_color", color)
	_transition_dim.modulate.a = 0.0
	_transition_panel.scale = Vector2(0.55, 0.55)
	_transition_layer.visible = true

	var tween: Tween = create_tween()
	tween.tween_property(_transition_dim, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(_transition_panel, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.55)
	tween.tween_property(_transition_dim, "modulate:a", 0.0, 0.2)
	await tween.finished
	_transition_layer.visible = false

	if next_scene.is_empty():
		GlobalTransition.reload_current_scene()
	else:
		GlobalTransition.change_scene_to_file(next_scene)


# ---------------------------------------------------------------------------
# 小工具
# ---------------------------------------------------------------------------

func _refresh_stat(key: String) -> void:
	var stat: AdventureLevelStat = _find_stat(key)
	if stat == null:
		return
	var saved: Dictionary = store.get_level_data(key)
	stat.solo_attempt = int(saved.get("solo_attempt", 0))
	stat.solo_pass = int(saved.get("solo_pass", 0))
	stat.solo_death = int(saved.get("solo_death", 0))
	stat.solo_skip = int(saved.get("solo_skip", 0))
	stat.solo_skip_soft = int(saved.get("solo_skip_soft", 0))
	stat.solo_last = int(saved.get("solo_last", 0))


func _find_stat(key: String) -> AdventureLevelStat:
	for stat: AdventureLevelStat in pool:
		if stat.key == key:
			return stat
	return null


func _fingerprint_for(key: String) -> String:
	var stat: AdventureLevelStat = _find_stat(key)
	return "" if stat == null else stat.fingerprint


func _fingerprints_for(keys: Array[String]) -> Array:
	var result: Array = []
	for key: String in keys:
		result.append(_fingerprint_for(key))
	return result


func _make_run_id() -> String:
	var stamp: String = Time.get_datetime_string_from_system(false, true)
	return stamp.replace(":", "-").replace(" ", "_")
