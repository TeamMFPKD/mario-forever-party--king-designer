extends Node

class_name PlayerSuit

signal suit_changed
signal play_sound_powerup
signal play_sound_powerdown

enum SuitType {
	SMALL,
	SUPER,
	POWERED,
}

enum PowerupType {
	FIREBALL,
	BEETROOT,
	LUI,
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

func _on_player_powerdown():
	if suit == SuitType.POWERED:
		suit = SuitType.SUPER
	elif suit == SuitType.SUPER:
		suit = SuitType.SMALL
	if suit == SuitType.SMALL:
		power = PowerupType.FIREBALL
