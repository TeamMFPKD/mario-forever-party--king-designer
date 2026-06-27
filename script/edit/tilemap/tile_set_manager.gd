extends Node

class_name TileSetManager

@export var database_holder: DatabaseHolder
@export var tile_map: TileMapLayer

func update_tile_set(level_theme: LevelManager.LevelThemeEnum) -> void:
	if tile_map != null:
		tile_map.tile_set = database_holder.tile_map_block_database.tile_map_block_database_entry[level_theme].tile_set
	else:
		push_error("TileMap is null!")
