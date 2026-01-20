extends Node2D

class_name Spawner

@export var spawn_object_scene : PackedScene

var isInLevel: bool

func _ready() -> void:
	if !isInLevel:
		return

	var offset_marker = $"OffsetMarker" as Marker2D
	var offset = offset_marker.position

	var create = func():
		if spawn_object_scene == null:
			push_error("%s: Spawn object scene is null!" % self.name)
		else:
			var spawn_object = spawn_object_scene.instance()
			spawn_object.position = offset
			add_sibling(spawn_object)
	create.call_deferred()
	
