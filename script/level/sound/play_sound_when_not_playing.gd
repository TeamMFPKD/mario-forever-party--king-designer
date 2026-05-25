extends ContinuousAudioStream

func play_sound_when_not_playing() -> void:
	if not playing:
		play()