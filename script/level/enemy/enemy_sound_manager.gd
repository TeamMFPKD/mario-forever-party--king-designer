extends Node

class_name EnemySoundManager

@export var play_sound_stomped: bool = true
@export var play_sound_kicked: bool = true
@export var play_sound_bumped: bool = true

var interaction_with_player: InteractionWithPlayer
var interaction_with_fireball: InteractionWithFireball
var interaction_with_beetroot: InteractionWithBeetroot
var interaction_with_star: InteractionWithStar
var interaction_with_shell: InteractionWithShell
var interaction_with_bump: InteractionWithBump

var sound_stomped: AudioStreamPlayer
var sound_kicked: AudioStreamPlayer
var sound_bumped: AudioStreamPlayer

func _ready() -> void:
	sound_stomped = get_node("Stomped") as AudioStreamPlayer
	sound_kicked = get_node("Kicked") as AudioStreamPlayer
	sound_bumped = get_node("Bumped") as AudioStreamPlayer

	var parent = get_parent()
	interaction_with_player = parent.get_meta("interaction_with_player") as InteractionWithPlayer
	interaction_with_fireball = parent.get_meta("interaction_with_fireball") as InteractionWithFireball
	
	if play_sound_stomped:
		interaction_with_player.stomped.connect(play_stomped)
	if play_sound_kicked:
		interaction_with_fireball.fireball_hitted.connect(play_kicked)
		interaction_with_beetroot.beetroot_hitted.connect(play_kicked)
		interaction_with_star.star_hitted.connect(play_kicked)
		interaction_with_shell.shell_hitted.connect(play_kicked)
	if play_sound_bumped:
		interaction_with_bump.bumped.connect(play_bumped)

func play_stomped() -> void:
	sound_stomped.play()

func play_kicked() -> void:
	sound_kicked.play()

func play_bumped() -> void:
	sound_bumped.play()