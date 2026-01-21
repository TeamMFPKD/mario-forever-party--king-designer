extends Node

@export var tile_map: TileMapLayer

enum TileSetNames {
	CASTLE,
	CAVE,
	DUSK,
	NIGHT,
	OVERWORLD,
	SAND,
	SNOW,
}

@export var tilesets: Dictionary[TileSetNames, TileSet]

func _physics_process(delta: float) -> void:
	if (Input.is_key_pressed(KEY_1)):
		tile_map.tile_set = tilesets[TileSetNames.CASTLE]
	elif (Input.is_key_pressed(KEY_2)):
		tile_map.tile_set = tilesets[TileSetNames.CAVE]
	elif (Input.is_key_pressed(KEY_3)):
		tile_map.tile_set = tilesets[TileSetNames.DUSK]
	elif (Input.is_key_pressed(KEY_4)):
		tile_map.tile_set = tilesets[TileSetNames.NIGHT]
	elif (Input.is_key_pressed(KEY_5)):
		tile_map.tile_set = tilesets[TileSetNames.OVERWORLD]
	elif (Input.is_key_pressed(KEY_6)):
		tile_map.tile_set = tilesets[TileSetNames.SAND]
	elif (Input.is_key_pressed(KEY_7)):
		tile_map.tile_set = tilesets[TileSetNames.SNOW]
		