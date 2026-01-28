extends Node2D

class_name BgpManager

@export var database_holder: DatabaseHolder

var bgp: BackgroundSet

func update_bgp(level_theme: LevelManager.LevelThemeEnum) -> void:
	if bgp != null:
		bgp.free()
	var bgp_scene: PackedScene
	bgp_scene = database_holder.background_database.background_entries[level_theme].background_scene
	bgp = bgp_scene.instantiate() as BackgroundSet
	bgp.position = position
	var add_bgp = func(node2d: BackgroundSet) -> void:
		add_sibling(node2d)
		node2d.background_set()
	add_bgp.call_deferred(bgp)
