extends CanvasLayer

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 百人团「每通过 2 关 +1 命」的奖励演出。
##
## 挂在 autoload Adventure 下常驻，因此过关转场中途换场景也不会被打断。
## 文字在左侧关卡信息面板的命数行附近生成：
##   上划淡入 → 停顿 0.5s → 上划淡出，同时播放 1UP 音效。
## 字体沿用全局主题 mfmp_theme.tres，只覆盖颜色（黄字 + 黑描边）与字号。
##
## 过关转场期间 get_tree().paused = true，Tween 会停住，所以这里和
## AdventureClearTransition 一样用 PROCESS_MODE_ALWAYS + _process(delta) 手动推进。

const THEME: Theme = preload("res://mfmp_theme.tres")
const ONE_UP_SOUND: AudioStream = preload("res://sound/level/1up.se.wav")

const RISE_DISTANCE: float = 44.0
const FADE_IN_SEC: float = 0.28
const HOLD_SEC: float = 0.5
const FADE_OUT_SEC: float = 0.28
const HOLD_END: float = FADE_IN_SEC + HOLD_SEC
const TOTAL_SEC: float = HOLD_END + FADE_OUT_SEC

const LABEL_WIDTH: float = 260.0
const LABEL_HEIGHT: float = 80.0

## 生成点相对「命数行」中心的纵向偏移；负值 = 往上。
const SPAWN_Y_OFFSET: float = -30.0


## 一个飘字的播放状态。用强类型容器，避免从 Variant 取值的警告（本工程把警告当错误）。
class FloatLabel extends RefCounted:
	var label: Label
	var elapsed: float = 0.0
	var start_y: float = 0.0

	func _init(l: Label, y: float) -> void:
		label = l
		start_y = y


var _sound: AudioStreamPlayer
var _floats: Array[FloatLabel] = []


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

	_sound = AudioStreamPlayer.new()
	_sound.name = "OneUpSound"
	_sound.stream = ONE_UP_SOUND
	add_child(_sound)

	Adventure.life_bonus.connect(_on_life_bonus)


func _on_life_bonus() -> void:
	_sound.play()

	var label: Label = _make_label()
	var start: Vector2 = _spawn_position()
	label.position = start
	label.modulate.a = 0.0
	add_child(label)
	_floats.append(FloatLabel.new(label, start.y))
	set_process(true)


func _process(delta: float) -> void:
	for i: int in range(_floats.size() - 1, -1, -1):
		var state: FloatLabel = _floats[i]
		if not is_instance_valid(state.label):
			_floats.remove_at(i)
			continue
		state.elapsed += delta
		var t: float = state.elapsed
		var y: float = state.start_y
		if t < FADE_IN_SEC:
			var k: float = t / FADE_IN_SEC
			state.label.modulate.a = k
			state.label.position.y = y - RISE_DISTANCE * k
		elif t < HOLD_END:
			state.label.modulate.a = 1.0
			state.label.position.y = y - RISE_DISTANCE
		elif t < TOTAL_SEC:
			var k: float = (t - HOLD_END) / FADE_OUT_SEC
			state.label.modulate.a = 1.0 - k
			state.label.position.y = y - RISE_DISTANCE * (1.0 + k)
		else:
			state.label.queue_free()
			_floats.remove_at(i)
	if _floats.is_empty():
		set_process(false)


func _make_label() -> Label:
	var label: Label = Label.new()
	label.theme = THEME
	label.text = "1UP"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.12))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(LABEL_WIDTH, LABEL_HEIGHT)
	return label


## 取当前场景里左侧面板「命数行」的全局位置；换场景间隙找不到时，
## 用面板固定布局（x=24..300、y=280 起）兜底。
func _spawn_position() -> Vector2:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var info: Control = scene.find_child("AdventureLevelInfo", true, false) as Control
		if info != null:
			var row: Control = info.find_child("LivesRow", true, false) as Control
			if row != null:
				var rect: Rect2 = row.get_global_rect()
				return Vector2(
					rect.position.x + rect.size.x * 0.5 - LABEL_WIDTH * 0.5,
					rect.position.y + rect.size.y * 0.5 - LABEL_HEIGHT * 0.5 + SPAWN_Y_OFFSET
				)
	return Vector2(24.0 + 138.0 - LABEL_WIDTH * 0.5, 272.0)
