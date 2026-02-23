extends Node

class_name BonusSet

signal bonus_get

enum BonusType {
	MUSHROOM,
	FIRE_FLOWER,
	BEETROOT,
	LUI,
	STAR,
}

@export var bonus_type : BonusType = BonusType.MUSHROOM
@export var path_to_parent : NodePath = ".."

var parent : Node2D

func _ready():
	parent = get_node(path_to_parent)
	parent.set_meta("bonus_set", self)

func on_bonus_get(_player: Node2D):
	emit_signal("bonus_get")
	parent.queue_free()
