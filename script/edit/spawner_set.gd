extends Node2D

class_name Spawner

@export var spawn_object_scene: PackedScene
@export var sprites: Array[Texture2D] = []

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
			spawn()
	create.call_deferred()
	
func spawn() -> void:
	var spawn_object = spawn_object_scene.instantiate() as Node2D
	spawn_object.position = position + offset
	add_sibling(spawn_object)
	visible = false
	
	# 如果有door_id meta，设置到spawn出来的对象
	if has_meta("door_id"):
		var door_id = get_meta("door_id")
		var door_component = spawn_object.get_node_or_null("Area2D/DoorComponent")
		if door_component and door_component.has_method("set_door_id"):
			door_component.set_door_id(door_id)
func in_level_check() -> bool:
	return GameModeSingleton.game_mode == GameModeSingleton.GameModeType.TEST \
	or GameModeSingleton.game_mode == GameModeSingleton.GameModeType.PLAY \
	or GameModeSingleton.game_mode == GameModeSingleton.GameModeType.HISTORY_PLAY