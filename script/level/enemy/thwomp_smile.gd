extends Area2D

@export var smile_sound: AudioStreamPlayer
@export var ani: AnimatedSprite2D

func _on_body_entered(body):
	if body.is_in_group("player"):
		if not smile_sound.is_playing():
			smile_sound.play()
			ani.play(&"laugh")

func _on_stun_finished():
	ani.play(&"default")
