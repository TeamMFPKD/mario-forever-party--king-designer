extends Node

class_name EnemySoundManager

@export var play_sound_stomped: bool = true
@export var play_sound_kicked: bool = true
@export var play_sound_bumped: bool = true

var interaction_with_player: InteractionWithPlayer
var sound_stomped: AudioStreamPlayer
var sound_kicked: AudioStreamPlayer
var sound_bumped: AudioStreamPlayer

func _ready() -> void:
	sound_stomped = get_node("Stomped") as AudioStreamPlayer
	sound_kicked = get_node("Kicked") as AudioStreamPlayer
	sound_bumped = get_node("Bumped") as AudioStreamPlayer

	var parent = get_parent()
	interaction_with_player = parent.get_meta("interaction_with_player") as InteractionWithPlayer
	
	if play_sound_stomped:
		interaction_with_player.stomped.connect(play_stomped)
	# Fireball, Beetroot, Bump, etc.
	#if play_sound_kicked:
	#	interaction_with_player.play_sound_kicked.connect(play_kicked)
	#if play_sound_bumped:
	#	interaction_with_player.play_sound_bumped.connect(play_bumped)

func play_stomped() -> void:
	sound_stomped.play()

func play_kicked() -> void:
	sound_kicked.play()

func play_bumped() -> void:
	sound_bumped.play()