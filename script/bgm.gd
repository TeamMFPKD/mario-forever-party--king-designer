extends ContinuousAudioStream

@export var sound_effect : bool:
	set(value):
		sound_effect = value
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Edit"), 0, sound_effect)

func _ready() -> void:
	# 初始化触发一次 set 方法
	sound_effect = sound_effect
