extends ContinuousAudioStream

class_name PinkCoinGetSound

@export var get_sounds: Array[AudioStream]
@export var all_get_sounds: Array[AudioStream]

func play_get(obtained_index: int, total_coins: int) -> void:
	if obtained_index < total_coins - 1:
		if obtained_index >= 0 and obtained_index < get_sounds.size():
			stream = get_sounds[obtained_index]
	else:
		var all_index = total_coins - 1
		if all_index >= 0 and all_index < all_get_sounds.size():
			stream = all_get_sounds[all_index]
	play()
