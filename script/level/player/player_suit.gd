extends Node

class_name PlayerSuit

signal suit_changed
signal play_sound_powerup
signal play_sound_powerdown

signal starman_started
signal starman_ended

enum SuitType {
	SMALL,
	SUPER,
	POWERED,
}

enum PowerupType {
	FIREBALL,
	BEETROOT,
	LUI,
	BIG,
}

@export var suit: SuitType = SuitType.SMALL:
	set(value):
		if int(suit) <= int(value):
			emit_signal("play_sound_powerup")
		else:
			emit_signal("play_sound_powerdown")
		if suit != value:
			suit = value
			emit_signal("suit_changed")

@export var power: PowerupType = PowerupType.FIREBALL:
	set(value):
		if power != value:
			power = value
			emit_signal("suit_changed")
			emit_signal("play_sound_powerup")

var is_starman : bool = false:
	set(value):
		is_starman = value
		starman_timer = 0
		if is_starman:
			emit_signal("starman_started")
		else:
			emit_signal("starman_ended")

@export var starman_time : int = 500
var starman_timer : int

func _physics_process(_delta: float) -> void:
	if is_starman:
		starman_timer += 1
		if starman_timer >= starman_time:
			is_starman = false

func _on_player_powerdown():
	if suit == SuitType.POWERED:
		suit = SuitType.SUPER
	elif suit == SuitType.SUPER:
		suit = SuitType.SMALL
	if suit == SuitType.SMALL:
		power = PowerupType.FIREBALL

func starman_start():
	is_starman = true