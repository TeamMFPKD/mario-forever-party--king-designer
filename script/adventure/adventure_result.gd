extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 百人团结算页的共用逻辑（挂在 object/ui/adventure_result_base.tscn 上）。
##
## GAME OVER / GAME CLEAR 是两张独立场景，各自实例本基础场景：
##   - 背景色、运动斜纹、标题字母行、专属 BGM 由结局场景自己提供；
##   - 这里只负责标题裁剪框、数据表、按钮，以及两者共用的演出与数据绑定。
## 结局场景覆写 is_game_clear 决定配色，标题行统一命名为 TitleClip/TitleRow。
##
## 演出分两套：
## - GAME OVER：标题逐字从裁剪框上沿掉落（DropInAnimation），掉完后数据表上划淡入；
## - GAME CLEAR：标题逐字直接出现在目标位置，带初速度受重力影响，落到目标 y 会反弹
##   （LetterBounceAnimation），弹稳后数据表再上划淡入。
## 数据来自 Adventure.last_summary（内存），不读 MPManager。

const STAGE_SCENE: String = "res://room/adventure_stage.tscn"
const TITLE_SCENE: String = "res://room/title.tscn"

## 相邻字母开始下落的间隔（秒）
const LETTER_STAGGER: float = 0.075
## 字母初始位置额外高出裁剪框的距离，保证完全看不见
const LETTER_DROP_MARGIN: float = 80.0
## 最后一颗字母落稳后，等多久开始显示数据
const DATA_AFTER_LETTERS_DELAY: float = 0.18
## 数据表格上划距离与时长
const DATA_RISE_DISTANCE: float = 110.0
const DATA_FADE_TIME: float = 0.5

## GAME CLEAR：相邻字母开始弹跳的间隔（秒）
const CLEAR_LETTER_STAGGER: float = 0.09
## GAME CLEAR：等最后一颗字母弹稳的最长等待（秒），兜底防止数据表永远不出现
const CLEAR_LETTERS_TIMEOUT: float = 4.0

const TIER_NAMES: Array[String] = ["简单", "普通", "困难", "超难"]

## GAME CLEAR 是浅色底：数据改深棕（白字加黑描边在浅色背景上糊成一团）。
const CLEAR_TEXT_COLOR: Color = Color(0.231373, 0.160784, 0.070588, 1.0)
const CLEAR_CAPTION_COLOR: Color = Color(0.231373, 0.160784, 0.070588, 0.68)
## 表头字号上限：结算页里 <= 该值的 Label 当表头（颜色更淡）。
const CAPTION_FONT_SIZE: int = 30

## 由 GAME OVER / GAME CLEAR 两个场景覆写。
@export var is_game_clear: bool = false
@export var title_clip: Control
@export var data_block: VBoxContainer
@export var tier_value: Label
@export var passed_value: Label
@export var deaths_value: Label
@export var excluded_value: Label
@export var skipped_value: Label

var _title_row: HBoxContainer
var _data_rest_y: float = 0.0
var _letters: Array[DropInAnimation] = []
## GAME CLEAR 用的逐字弹跳动画（与 GAME OVER 的掉落动画分开存）
var _bounce_letters: Array[LetterBounceAnimation] = []


func _ready() -> void:
	# 结算页是冻结着关卡切进来的，这里负责解冻。
	get_tree().paused = false
	# 专属 BGM 由结局场景的 RoomBgm 节点负责：进场停掉挑战曲、淡入结算曲。
	_title_row = get_node_or_null("TitleClip/TitleRow") as HBoxContainer
	_apply_mode()
	_bind_summary(Adventure.last_summary)
	_fit_row(_title_row)
	_prepare_letters(_title_row)
	call_deferred("_play_intro")


# ---------------------------------------------------------------------------
# 版式
# ---------------------------------------------------------------------------

func _apply_mode() -> void:
	if is_game_clear:
		_apply_clear_text_style()
	title_clip.visible = true
	if _title_row != null:
		# 标题行先摆出来但全透明：容器只给可见的子节点排版，
		# 排版没落定就采样静止位置，字母会停在偏掉的地方（见 _wait_layout_ready）。
		# GAME CLEAR 的字母各自淡入，行本身保持不透明；
		# GAME OVER 由 _play_intro 统一淡入整行。
		_title_row.visible = true
		_title_row.modulate.a = 0.0


## 浅色底上用深棕字，表头再淡一档，描边压到 2px 保留统一的黑描边。
func _apply_clear_text_style() -> void:
	for node: Node in data_block.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label == null:
			continue
		var caption: bool = label.get_theme_font_size("font_size") <= CAPTION_FONT_SIZE
		label.add_theme_color_override(
			"font_color",
			CLEAR_CAPTION_COLOR if caption else CLEAR_TEXT_COLOR
		)
		label.add_theme_constant_override("outline_size", 2)


## 字母 Label 的字宽由字体决定，运行期把每个槽位撑到字形大小；
## 容器只负责摆槽位，动画作用在槽位里的 Label 上，不会被 HBox 重排抹掉。
func _fit_row(row: HBoxContainer) -> void:
	if row == null:
		return
	for child: Node in row.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		var letter: Label = slot.get_node_or_null("Letter") as Label
		if letter == null:
			continue
		var minimum: Vector2 = letter.get_minimum_size()
		slot.custom_minimum_size = Vector2(minimum.x + 10.0, minimum.y + 8.0)


## 等标题行排版稳定再开始演出。
##
## 主题字体是懒加载的：字体换上之前，字母 Label 用的是默认字体，最小高度比
## 换上之后小一截，槽位按旧字形撑出来的尺寸就偏了，字母会被撑成
## 「比槽位高出一截」，采样到的静止位置也跟着偏（实测第一个字母偏了 85px，
## 会停在半空）。
##
## 所以这里反复做两件事：按当前字形重新撑槽位、等排版落定。
## 判据：字母尺寸等于槽位尺寸、字母在槽位里的偏移归零（满幅锚定），
## 且字形最小尺寸连续两帧没再变（说明字体已经换上）。
func _wait_layout_ready() -> void:
	var guard: int = 30
	var last_min: Vector2 = Vector2.ZERO
	while guard > 0:
		_fit_row(_title_row)
		await get_tree().process_frame
		var minimum: Vector2 = _letters_min_size()
		if _layout_ready() and minimum == last_min:
			return
		last_min = minimum
		guard -= 1


## 第一个字母的最小尺寸：所有字母同字号同字体，取一个就够。
func _letters_min_size() -> Vector2:
	if _title_row == null:
		return Vector2.ZERO
	for child: Node in _title_row.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		var letter: Label = slot.get_node_or_null("Letter") as Label
		if letter == null:
			continue
		return letter.get_minimum_size()
	return Vector2.ZERO


func _layout_ready() -> bool:
	if _title_row == null:
		return true
	for child: Node in _title_row.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		var letter: Label = slot.get_node_or_null("Letter") as Label
		if letter == null:
			continue
		if slot.size.y <= 0.0 or letter.size != slot.size:
			return false
		if absf(letter.position.y) > 0.5 or absf(letter.position.x) > 0.5:
			return false
	return true


func _prepare_letters(row: HBoxContainer) -> void:
	_letters.clear()
	_bounce_letters.clear()
	if row == null:
		return
	if is_game_clear:
		_prepare_clear_letters(row)
		return
	var fall: float = title_clip.size.y + LETTER_DROP_MARGIN
	for child: Node in row.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		var letter: Label = slot.get_node_or_null("Letter") as Label
		if letter == null:
			continue
		var drop: DropInAnimation = DropInAnimation.new()
		drop.name = "DropIn"
		drop.target_path = ^".."
		drop.panel_path = ^""
		drop.watch_path = ^""
		drop.drop_distance = fall
		letter.add_child(drop)
		_letters.append(drop)


## GAME CLEAR：字母不走「从遮罩上沿掉进来」，改成在目标位置直接出现，
## 再由重力动画负责弹跳落位（淡入也在动画脚本里做，逐字错峰才看得出「一个一个出现」）。
func _prepare_clear_letters(row: HBoxContainer) -> void:
	for child: Node in row.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		var letter: Label = slot.get_node_or_null("Letter") as Label
		if letter == null:
			continue
		var bounce: LetterBounceAnimation = LetterBounceAnimation.new()
		bounce.name = "Bounce"
		bounce.target_path = ^".."
		letter.add_child(bounce)
		_bounce_letters.append(bounce)


# ---------------------------------------------------------------------------
# 数据
# ---------------------------------------------------------------------------

func _bind_summary(summary: Dictionary) -> void:
	if summary.is_empty():
		tier_value.text = "--"
		passed_value.text = "--"
		deaths_value.text = "--"
		excluded_value.text = "--"
		skipped_value.text = "--"
		return

	var mode: String = str(summary.get("mode", "finite"))
	var cleared: int = int(summary.get("cleared_count", 0))
	var total: int = int(summary.get("total_levels", -1))
	if mode == "finite":
		passed_value.text = "%d/%d" % [cleared, maxi(total, 0)]
	else:
		passed_value.text = str(cleared)

	deaths_value.text = str(int(summary.get("deaths", 0)))
	excluded_value.text = str(int(summary.get("skipped_hard", 0)))
	skipped_value.text = str(int(summary.get("skipped_soft", 0)))
	tier_value.text = _tier_text(int(summary.get("tier", 0)))


func _tier_text(tier: int) -> String:
	if tier >= 1 and tier <= TIER_NAMES.size():
		return TIER_NAMES[tier - 1]
	return "随机"


# ---------------------------------------------------------------------------
# 演出
# ---------------------------------------------------------------------------

func _play_intro() -> void:
	if _title_row == null:
		_show_data()
		return
	# 标题行在 _apply_mode 里已经摆出来（透明），这里等排版落定再开始演出，
	# 否则字母可能在 x=0 处起跳、或停在偏掉的静止位置上。
	await _wait_layout_ready()
	if is_game_clear:
		# GAME CLEAR 的字母各自淡入，标题行本身保持不透明。
		_title_row.modulate.a = 1.0
		await get_tree().process_frame
		await _play_clear_intro()
		return
	_title_row.modulate.a = 0.0
	await get_tree().process_frame
	_title_row.modulate.a = 1.0

	# 数据表同样等排版完成后采样静止位置，再挪到下方准备上划。
	_data_rest_y = data_block.position.y
	data_block.modulate.a = 0.0
	data_block.position.y = _data_rest_y + DATA_RISE_DISTANCE
	data_block.visible = false

	if _letters.is_empty():
		_show_data()
		return

	for index: int in range(_letters.size()):
		var drop: DropInAnimation = _letters[index]
		drop.start_delay = float(index) * LETTER_STAGGER
		drop.play_drop_in()

	var wait: float = float(_letters.size() - 1) * LETTER_STAGGER
	wait += DropInAnimation.DROP_TIME
	for seconds: float in DropInAnimation.BOUNCE_TIMES:
		wait += seconds
	wait += DATA_AFTER_LETTERS_DELAY
	await get_tree().create_timer(wait).timeout
	_show_data()


## GAME CLEAR：逐字弹跳入场。等最后一颗字母弹稳再上划数据表。
func _play_clear_intro() -> void:
	# 数据表同样等排版完成后采样静止位置，再挪到下方准备上划。
	_data_rest_y = data_block.position.y
	data_block.modulate.a = 0.0
	data_block.position.y = _data_rest_y + DATA_RISE_DISTANCE
	data_block.visible = false

	if _bounce_letters.is_empty():
		_show_data()
		return

	for index: int in range(_bounce_letters.size()):
		var bounce: LetterBounceAnimation = _bounce_letters[index]
		bounce.start_delay = float(index) * CLEAR_LETTER_STAGGER
		bounce.play()

	await _wait_letters_settled(_bounce_letters[_bounce_letters.size() - 1])
	await get_tree().create_timer(DATA_AFTER_LETTERS_DELAY).timeout
	_show_data()


## 等最后一颗字母弹跳停稳；动画异常时用超时兜底，别让数据表永远不出现。
func _wait_letters_settled(last: LetterBounceAnimation) -> void:
	var guard: float = CLEAR_LETTERS_TIMEOUT
	while guard > 0.0:
		if last == null or not is_instance_valid(last):
			return
		if last.is_finished():
			return
		await get_tree().process_frame
		guard -= get_process_delta_time()


func _show_data() -> void:
	if not is_inside_tree():
		return
	data_block.visible = true
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(data_block, "position:y", _data_rest_y, DATA_FADE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(data_block, "modulate:a", 1.0, DATA_FADE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# 按钮
# ---------------------------------------------------------------------------

func _on_again_pressed() -> void:
	var settings: Dictionary = Adventure.get_settings()
	if Adventure.start_run(settings):
		GlobalTransition.change_scene_to_file(Adventure.PLAY_SCENE)
	else:
		GlobalTransition.change_scene_to_file(STAGE_SCENE)


func _on_stage_pressed() -> void:
	GlobalTransition.change_scene_to_file(STAGE_SCENE)


func _on_title_pressed() -> void:
	Adventure.stop_bgm()
	GlobalTransition.change_scene_to_file(TITLE_SCENE)
