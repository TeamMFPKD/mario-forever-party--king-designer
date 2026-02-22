extends HSlider

enum VolumeType {
	MASTER,
	MUSIC,
	SOUND,
}

# 字典映射VolumeType到bus名称
var bus_names = {
	VolumeType.MASTER: "Master",
	VolumeType.MUSIC: "Music", 
	VolumeType.SOUND: "Sound",
}

@export var volume_type = VolumeType.MASTER

var config

func _ready() -> void:
	config = GameConfig.config

	var bus_name = bus_names[volume_type]
	var bus_index = AudioServer.get_bus_index(bus_name)

	AudioServer.set_bus_volume_linear(bus_index, config.get_value("volume", bus_name, 1))
	value = AudioServer.get_bus_volume_linear(bus_index)

	drag_ended.connect(_on_drag_ended)

func _on_drag_ended(is_new_value: bool) -> void:
	if not is_new_value:
		return

	var bus_name = bus_names[volume_type]
	var bus_index = AudioServer.get_bus_index(bus_name)

	AudioServer.set_bus_volume_linear(bus_index, value)
	config.set_value("volume", bus_name, get_value())

	GameConfig.save()
