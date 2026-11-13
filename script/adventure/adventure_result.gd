extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 百人团结算页：GAME OVER / GAME CLEAR。
##
## 两种结局共用同一套演出：
##   1. 标题被裁在 TitleClip 里，逐字从裁剪框上沿掉落（复用 DropInAnimation
##      的自由落体 + 两次反弹，只是用 drop_distance 改成固定下落距离）；
##   2. 掉完后，下方数据卡片上划淡入，按钮跟着一起出现。
## 差别只有：GAME OVER 紫字 + 黑底运动 psc；GAME CLEAR 黄字 + 淡黄底。
##
## 数据来自 Adventure.last_summary（内存），不读 MPManager。

const STAGE_SCENE: String = "res://room/adventure_stage.tscn"
const TITLE_SCENE: String = "res://room/title.tscn"

## 相邻字母开始下落的间隔（秒）
const LETTER_STAGGER: float = 0.075
## 字母初始位置额外高出裁剪框的距离，保证完全看不见
const LETTER_DROP_MARGIN: float = 80.0
## 最后一颗字母落稳后，等多久开始显示数据
const DATA_AFTER_LETTERS_DELAY: float = 0.18
## 数据卡片上划距离与时长
const DATA_RISE_DISTANCE: float = 110.0
const DATA_FADE_TIME: float = 0.5

## GAME OVER 背景：psc.png 染成近黑，叠在黑底上只剩很淡的斜纹在动。
## GAME CLEAR 不叠 psc（psc 本身带绿色通道，乘黄色会发绿），直接露出淡黄底。
const OVER_PSC_TINT: Color = Color(0.13, 0.1, 0.18, 1.0)

const TIER_NAMES: Array[String] = ["轻松", "标准", "困难", "极限"]
const LIVES_CAP: int = 100

## GAME CLEAR 是浅色底：数据文字改深棕（白字加黑描边在浅色卡片上糊成一团）。
const CLEAR_TEXT_COLOR: Color = Color(0.231373, 0.160784, 0.070588, 1.0)

@export var clear_background: ColorRect
@export var over_background: ColorRect
@export var psc_sprite: Sprite2D
@export var title_clip: Control
@export var over_row: HBoxContainer
@export var clear_row: HBoxContainer
@export var data_block: PanelContainer
@export var result_label: Label
@export var passed_value: Label
@export var lives_value: Label
@export var skip_value: Label
@export var tier_value: Label
@export var over_card_style: StyleBoxFlat
@export var clear_card_style: StyleBoxFlat

var _game_clear: bool = false
var _data_rest_y: float = 0.0
var _letters: Array[DropInAnimation] = []


func _ready() -> void:
	# 结算页是冻结着关卡切进来的，这里负责解冻。
	get_tree().paused = false
	var summary: Dictionary = Adventure.last_summary
	_game_clear = str(summary.get("result", "")) == "completed"
	_apply_mode()
	_bind_summary(summary)
	_fit_row(over_row)
	_fit_row(clear_row)
	_prepare_letters(over_row if not _game_clear else clear_row)
	call_deferred("_play_intro")


# ---------------------------------------------------------------------------
# 版式
# ---------------------------------------------------------------------------

func _apply_mode() -> void:
	clear_background.visible = _game_clear
	over_background.visible = not _game_clear
	psc_sprite.visible = not _game_clear
	psc_sprite.self_modulate = OVER_PSC_TINT
	# 两行标题只显示一行；真正显示放在 _play_intro 里，避免入场前闪一帧完整标题。
	over_row.visible = false
	clear_row.visible = false
	data_block.add_theme_stylebox_override(
		"panel",
		clear_card_style if _game_clear else over_card_style
	)
	if _game_clear:
		_apply_clear_text_style()


## 浅色卡片上用深棕字，黑描边压到 2px：小字不至于糊成一团，又保留统一的黑描边。
func _apply_clear_text_style() -> void:
	for node: Node in data_block.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label == null:
			continue
		label.add_theme_color_override("font_color", CLEAR_TEXT_COLOR)
		label.add_theme_constant_override("outline_size", 2)


## 字母 Label 的字宽由字体决定，运行期把每个槽位撑到字形大小；
## 容器只负责摆槽位，动画作用在槽位里的 Label 上，不会被 HBox 重排抹掉。
func _fit_row(row: HBoxContainer) -> void:
	for child: Node in row.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		var letter: Label = slot.get_node_or_null("Letter") as Label
		if letter == null:
			continue
		var minimum: Vector2 = letter.get_minimum_size()
		slot.custom_minimum_size = Vector2(minimum.x + 10.0, minimum.y + 8.0)


func _prepare_letters(row: HBoxContainer) -> void:
	_letters.clear()
	if row == null:
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


# ---------------------------------------------------------------------------
# 数据
# ---------------------------------------------------------------------------

func _bind_summary(summary: Dictionary) -> void:
	if summary.is_empty():
		result_label.text = "没有可显示的团数据。"
		passed_value.text = "--"
		lives_value.text = "--"
		skip_value.text = "--"
		tier_value.text = "--"
		return

	result_label.text = _result_text(str(summary.get("result", "")))

	var mode: String = str(summary.get("mode", "finite"))
	var cleared: int = int(summary.get("cleared_count", 0))
	var total: int = int(summary.get("total_levels", -1))
	if mode == "finite":
		passed_value.text = "%d / %d" % [cleared, maxi(total, 0)]
	else:
		passed_value.text = "%d 关" % cleared

	var lives: int = int(summary.get("lives_left", 0))
	lives_value.text = "MAX" if lives >= LIVES_CAP else str(lives)

	skip_value.text = "%d / %d" % [
		int(summary.get("skipped_soft", 0)),
		int(summary.get("skipped_hard", 0)),
	]
	tier_value.text = _tier_text(int(summary.get("tier", 0)))


func _result_text(result: String) -> String:
	match result:
		"completed":
			return "走完了整条路线。"
		"failed":
			return "命数耗尽，本团失败。"
		"abandoned":
			return "你放弃了本团。"
		"no_levels":
			return "没有可玩的关卡了。"
		_:
			return ""


func _tier_text(tier: int) -> String:
	if tier >= 1 and tier <= TIER_NAMES.size():
		return "%d %s" % [tier, TIER_NAMES[tier - 1]]
	return "随机"


# ---------------------------------------------------------------------------
# 演出
# ---------------------------------------------------------------------------

func _play_intro() -> void:
	var row: HBoxContainer = clear_row if _game_clear else over_row
	# 先让标题行可见（透明）等一帧，保证 HBox 已经按字形宽度排好位置，
	# 否则字母可能在 x=0 处起跳、随后才被容器挪到正确位置。
	row.visible = true
	row.modulate.a = 0.0
	await get_tree().process_frame
	row.modulate.a = 1.0

	# 卡片同样等排版完成后采样静止位置，再挪到下方准备上划。
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
	GlobalTransition.change_scene_to_file(TITLE_SCENE)
