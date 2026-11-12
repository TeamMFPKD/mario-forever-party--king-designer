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
	store.set_run(current_run)
	GameModeSingleton.set("game_mode", GameMode.GameModeType.ADVENTURE)
	run_started.emit()
	run_changed.emit()
	return true


## load_level.gd 在关卡成功加载后调用。
func on_level_loaded(path: String) -> void:
	if not GameMode.is_history_play() and not GameMode.is_adventure():
		return
	var key: String = path.get_file()
	if key.is_empty():
		return
	current_key = key
	store.record_attempt(key)
	_refresh_stat(key)
	if is_running():
		run_changed.emit()


## goal_gate 在 ADVENTURE 场景由控制器调用；HISTORY_PLAY 由 goal_gate 直接调用。
func on_level_passed() -> void:
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


## HISTORY_PLAY 由 player_dead 直接调用；ADVENTURE 由控制器调用。
func on_player_died() -> void:
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

	store.set_run(current_run)
	advance()


func abandon_run() -> void:
	if not is_running():
		return
	finish_run("abandoned")


# ---------------------------------------------------------------------------
# 推进内部
# ---------------------------------------------------------------------------

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


## kind: pass / skip / death / finish；next_scene 为空时重载当前场景。
func play_transition(kind: String, next_scene: String = "") -> void:
	# 过关优先在关卡视口里播前端转场（只覆盖 640×480 的游戏画面）
	if kind == "pass" and is_instance_valid(_clear_transition):
		var cleared: int = int(current_run.get("cleared_count", 1))
		var total: int = int(current_run.get("total_levels", -1))
		_clear_transition.call("play", cleared, total)
		var waited: float = 0.0
		while is_instance_valid(_clear_transition) and _clear_transition.visible and waited < 6.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
		if next_scene.is_empty():
			GlobalTransition.reload_current_scene()
		else:
			GlobalTransition.change_scene_to_file(next_scene)
		return

	if _transition_layer == null:
		if next_scene.is_empty():
			GlobalTransition.reload_current_scene()
		else:
			GlobalTransition.change_scene_to_file(next_scene)
		return

	var symbol: String = "✓"
	var color: Color = Color("#2E9E5B")
	match kind:
		"skip":
			symbol = "→"
			color = Color("#D39B22")
		"death":
			symbol = "✗"
			color = Color("#C74343")
		"finish":
			symbol = "★"
			color = Color("#8A5BD6")
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
