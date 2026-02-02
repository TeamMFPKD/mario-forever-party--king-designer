extends ContinuousAudioStream

func _on_player_skid() -> void:
	if not playing:
		play()
