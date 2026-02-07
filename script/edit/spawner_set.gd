extends Node2D

class_name Spawner

@export var spawn_object_scene : PackedScene

var is_in_level: bool
var offset: Vector2

func _ready() -> void:
	is_in_level = in_level_check()

	if !is_in_level:
		return

	var offset_marker = $"OffsetMarker" as Marker2D
	offset = offset_marker.position

	var create = func():
		if spawn_object_scene == null:
			push_error("%s: Spawn object scene is null!" % self.name)
		else:
			spawn_object()
	create.call_deferred()
	
func spawn_object() -> void:
	var spawn_object = spawn_object_scene.instantiate() as Node2D
	spawn_object.position = position + offset
	add_sibling(spawn_object)
	visible = false

func in_level_check() -> bool:
	return GameModeSingleton.game_mode != GameModeSingleton.GameModeType.EDIT