extends HSlider

enum VolumeType {
	MASTER,
	MUSIC,
	SOUND,
	UI,
}

# 字典映射VolumeType到bus名称
var bus_names: Dictionary = {
	VolumeType.MASTER: "Master",
	VolumeType.MUSIC: "Music", 
	VolumeType.SOUND: "Sound",
	VolumeType.UI: "UI",
}

@export var volume_type: VolumeType = VolumeType.MASTER

var config: ConfigFile

## 初始化赋值时也要触发 value_changed，用一个标记挡住，别把默认值当成用户操作落盘
var _initializing: bool = false
## 连按方向键 / 拖动时值会连续变化，写盘防抖
var _save_timer: SceneTreeTimer = null

func _ready() -> void:
	config = GameConfig.config

	var bus_name: String = bus_names[volume_type]
	var bus_index: int = AudioServer.get_bus_index(bus_name)

	var saved_volume: float = config.get_value("volume", bus_name, 1)
	AudioServer.set_bus_volume_linear(bus_index, saved_volume)

	_initializing = true
	value = AudioServer.get_bus_volume_linear(bus_index)
	_initializing = false

	value_changed.connect(_on_value_changed)
	drag_ended.connect(_on_drag_ended)


## 值一变就生效。键盘调值（方向键选到滑块）不会触发 drag_ended，
## 所以这里同时负责写 config，落盘交给 _schedule_save 防抖。
func _on_value_changed(new_value: float) -> void:
	if _initializing:
		return
	var bus_name: String = bus_names[volume_type]
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus_name), new_value)
	config.set_value("volume", bus_name, new_value)
	_schedule_save()


func _on_drag_ended(is_new_value: bool) -> void:
	if not is_new_value:
		return
	var bus_name: String = bus_names[volume_type]
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_linear(bus_index, value)
	config.set_value("volume", bus_name, get_value())
	GameConfig.save()


func _schedule_save() -> void:
	if _save_timer != null:
		return
	_save_timer = get_tree().create_timer(0.4)
	_save_timer.timeout.connect(_flush_save)


func _flush_save() -> void:
	_save_timer = null
	GameConfig.save()
