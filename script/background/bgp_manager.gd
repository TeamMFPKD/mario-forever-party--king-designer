extends Node2D

class_name BgpManager

@export var database_holder: DatabaseHolder

var bgp: Node

func update_bgp(level_theme: LevelManager.LevelThemeEnum) -> void:
	if bgp != null:
		bgp.free()
	var bgp_scene: PackedScene
	bgp_scene = database_holder.background_database.background_entries[level_theme].background_scene
	bgp = bgp_scene.instantiate() as Node2D
	bgp.position = position
	add_sibling(bgp)
