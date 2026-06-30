extends Node

signal play_sound_shoot

@export var path_to_parent: NodePath = ".."
@export var path_to_shoot_position_marker: NodePath = "../ShootMarker"
@export var piranha_fireball_scene: PackedScene = preload("uid://bdmb70v8ygg5c")

var shoot_position_marker: Node2D
var parent: Node2D
var player: Node2D

func _ready():
	parent = get_node(path_to_parent)
	shoot_position_marker = get_node(path_to_shoot_position_marker)
	player = get_tree().get_first_node_in_group("player") as Node2D

func _on_shoot():
	var fireball = piranha_fireball_scene.instantiate() as Node2D
	fireball.position = shoot_position_marker.global_position
	if not player:
		player = get_tree().get_first_node_in_group("player") as Node2D
		if not player:
			push_error("Piranha shoot: Player not found.")
			return
	fireball.set_meta("fireball_direction", 1 if parent.global_position.x < player.global_position.x else -1)
	parent.add_sibling(fireball)
	emit_signal("play_sound_shoot")
