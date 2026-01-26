func update_theme() -> void:
	# Update TileMap and Background
	if tile_set_manager != null:
		tile_set_manager.update_tile_set(level_theme)
	else:
		push_error("TileSetManager is null! Please check the export reference in the scene.")
	
	if bgp_manager != null:
		bgp_manager.update_bgp(level_theme)
	else:
		push_error("BgpManager is null! Please check the export reference in the scene.")