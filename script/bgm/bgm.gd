extends ContinuousAudioStream

class_name BGM

@export var sound_effect : bool:
	set(value):
		sound_effect = value
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Edit"), 0, sound_effect)
