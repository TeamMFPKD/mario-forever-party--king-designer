extends Node

class_name LevelControl

enum DrawingMode {
	TILEMAP,
	OBJECTMAP,
	ERASER,
	CLEAR_PIPE,
}

signal drawing_mode_changed(mode: DrawingMode)
signal object_selected(object_name: String)
signal play_sound_place
signal play_sound_erase

var current_drawing_mode: DrawingMode = DrawingMode.TILEMAP
var current_object_name: String = ""

@export var tile_map_draw: TileMapDraw
@export var object_map_layer: ObjectMapLayer
@export var object_map_draw: Node
@export var clear_pipe_draw: Node

@export var tile_button: Button
@export var button_eraser: Button

func _ready() -> void:
	if tile_button:
		tile_button.pressed.connect(_on_tile_button_pressed)

	if button_eraser:
		button_eraser.pressed.connect(_on_eraser_button_pressed)

	switch_to_tilemap_mode()

func switch_to_tilemap_mode() -> void:
	current_drawing_mode = DrawingMode.TILEMAP
	current_object_name = ""

	reset_input_state()

	if tile_map_draw and tile_map_draw.has_method("set_drawing_enabled"):
		tile_map_draw.set_drawing_enabled(true)
		if tile_map_draw.has_method("set_brush_mode"):
			tile_map_draw.set_brush_mode(true)

		if tile_map_draw.has_method("clear_custom_atlas_coords"):
			tile_map_draw.clear_custom_atlas_coords()

	if object_map_layer and object_map_layer.has_method("stop_placing_object"):
		object_map_layer.stop_placing_object()
		object_map_layer.drawing_enabled = false

	if clear_pipe_draw and clear_pipe_draw.has_method("set_drawing_enabled"):
		clear_pipe_draw.call("set_drawing_enabled", false)

	drawing_mode_changed.emit(current_drawing_mode)

func switch_to_objectmap_mode(object_name: String) -> void:
	current_drawing_mode = DrawingMode.OBJECTMAP
	current_object_name = object_name

	reset_input_state()

	if tile_map_draw and tile_map_draw.has_method("set_drawing_enabled"):
		tile_map_draw.set_drawing_enabled(false)

	if object_map_layer and object_map_layer.has_method("start_placing_object"):
		object_map_layer.start_placing_object(object_name)
		object_map_layer.drawing_enabled = true

	if clear_pipe_draw and clear_pipe_draw.has_method("set_drawing_enabled"):
		clear_pipe_draw.call("set_drawing_enabled", false)

	drawing_mode_changed.emit(current_drawing_mode)
	object_selected.emit(object_name)

func switch_to_clear_pipe_mode(object_name: String) -> void:
	current_drawing_mode = DrawingMode.CLEAR_PIPE
	current_object_name = object_name

	reset_input_state()

	if tile_map_draw and tile_map_draw.has_method("set_drawing_enabled"):
		tile_map_draw.set_drawing_enabled(false)

	if object_map_layer and object_map_layer.has_method("stop_placing_object"):
		object_map_layer.stop_placing_object()
		object_map_layer.drawing_enabled = false

	if clear_pipe_draw and clear_pipe_draw.has_method("set_drawing_enabled"):
		clear_pipe_draw.call("set_drawing_enabled", true)

	drawing_mode_changed.emit(current_drawing_mode)
	object_selected.emit(object_name)

func switch_to_eraser_mode() -> void:
	current_drawing_mode = DrawingMode.ERASER
	current_object_name = ""

	reset_input_state()

	if tile_map_draw and tile_map_draw.has_method("set_drawing_enabled"):
		tile_map_draw.set_drawing_enabled(true)
		if tile_map_draw.has_method("set_brush_mode"):
			tile_map_draw.set_brush_mode(false)

	if object_map_layer and object_map_layer.has_method("stop_placing_object"):
		object_map_layer.stop_placing_object()
		object_map_layer.drawing_enabled = false

	if clear_pipe_draw and clear_pipe_draw.has_method("set_drawing_enabled"):
		clear_pipe_draw.call("set_drawing_enabled", false)

	drawing_mode_changed.emit(current_drawing_mode)

func _on_tile_button_pressed() -> void:
	switch_to_tilemap_mode()

func _on_eraser_button_pressed() -> void:
	switch_to_eraser_mode()

func switch_to_tilemap_mode_with_coords(custom_atlas_coords: Vector2i = Vector2i(-1, -1)) -> void:
	current_drawing_mode = DrawingMode.TILEMAP
	current_object_name = ""

	reset_input_state()

	if tile_map_draw and tile_map_draw.has_method("set_drawing_enabled"):
		tile_map_draw.set_drawing_enabled(true)
		if tile_map_draw.has_method("set_brush_mode"):
			tile_map_draw.set_brush_mode(true)

		if custom_atlas_coords != Vector2i(-1, -1) and tile_map_draw.has_method("set_custom_atlas_coords"):
			tile_map_draw.set_custom_atlas_coords(custom_atlas_coords)
		else:
			if tile_map_draw.has_method("clear_custom_atlas_coords"):
				tile_map_draw.clear_custom_atlas_coords()

	if object_map_layer and object_map_layer.has_method("stop_placing_object"):
		object_map_layer.stop_placing_object()
		object_map_layer.drawing_enabled = false

	if clear_pipe_draw and clear_pipe_draw.has_method("set_drawing_enabled"):
		clear_pipe_draw.call("set_drawing_enabled", false)

	drawing_mode_changed.emit(current_drawing_mode)

func get_current_drawing_mode() -> DrawingMode:
	return current_drawing_mode

func get_current_object_name() -> String:
	return current_object_name

func is_tilemap_mode() -> bool:
	return current_drawing_mode == DrawingMode.TILEMAP

func is_objectmap_mode() -> bool:
	return current_drawing_mode == DrawingMode.OBJECTMAP

func is_eraser_mode() -> bool:
	return current_drawing_mode == DrawingMode.ERASER

func is_clear_pipe_mode() -> bool:
	return current_drawing_mode == DrawingMode.CLEAR_PIPE

func erase_at_position(position: Vector2) -> void:
	if current_drawing_mode != DrawingMode.ERASER:
		return

	if clear_pipe_draw and clear_pipe_draw.has_method("erase_line_at_world_position"):
		if clear_pipe_draw.call("erase_line_at_world_position", position):
			emit_signal("play_sound_erase")
			return

	var has_tile: bool = false
	var has_object: bool = false

	if tile_map_draw and tile_map_draw.tile_map:
		var local_pos: Vector2 = tile_map_draw.to_local(position)
		var cell_size: Vector2i = tile_map_draw.tile_map.tile_set.tile_size
		var cell_coords: Vector2i = Vector2i(
			floori(local_pos.x / cell_size.x),
			floori(local_pos.y / cell_size.y)
		)
		has_tile = tile_map_draw.tile_map.get_cell_source_id(cell_coords) != -1

	if object_map_layer:
		var grid_position: Vector2 = object_map_layer.align_to_grid(position)
		has_object = object_map_layer.is_grid_position_occupied(grid_position)

	var should_emit_sound: bool = has_tile || has_object

	if tile_map_draw and tile_map_draw.has_method("erase_tile_at_position"):
		tile_map_draw.erase_tile_at_position(position)

	if object_map_layer and object_map_layer.has_method("remove_object_at_position"):
		should_emit_sound = object_map_layer.remove_object_at_position(position) && should_emit_sound

	if should_emit_sound:
		emit_signal("play_sound_erase")

func erase_at_position_immediate(position: Vector2) -> void:
	var has_tile: bool = false
	var has_object: bool = false

	if tile_map_draw and tile_map_draw.tile_map:
		var local_pos: Vector2 = tile_map_draw.to_local(position)
		var cell_size: Vector2i = tile_map_draw.tile_map.tile_set.tile_size
		var cell_coords: Vector2i = Vector2i(
			floori(local_pos.x / cell_size.x),
			floori(local_pos.y / cell_size.y)
		)
		has_tile = tile_map_draw.tile_map.get_cell_source_id(cell_coords) != -1

	if object_map_layer:
		var grid_position: Vector2 = object_map_layer.align_to_grid(position)
		has_object = object_map_layer.is_grid_position_occupied(grid_position)

	var should_emit_sound: bool = false

	match current_drawing_mode:
		DrawingMode.CLEAR_PIPE:
			if clear_pipe_draw and clear_pipe_draw.has_method("erase_line_at_world_position"):
				var erased_line: bool = clear_pipe_draw.call("erase_line_at_world_position", position)
				should_emit_sound = erased_line

		DrawingMode.TILEMAP:
			if has_tile and tile_map_draw and tile_map_draw.has_method("erase_tile_at_position"):
				tile_map_draw.erase_tile_at_position(position)
				should_emit_sound = has_tile

		DrawingMode.OBJECTMAP:
			if has_object and object_map_layer and object_map_layer.has_method("remove_object_at_position"):
				should_emit_sound = object_map_layer.remove_object_at_position(position)

		_:
			if clear_pipe_draw and clear_pipe_draw.has_method("erase_line_at_world_position"):
				if clear_pipe_draw.call("erase_line_at_world_position", position):
					should_emit_sound = true
			if tile_map_draw and tile_map_draw.has_method("erase_tile_at_position"):
				tile_map_draw.erase_tile_at_position(position)
			if object_map_layer and object_map_layer.has_method("remove_object_at_position"):
				should_emit_sound = object_map_layer.remove_object_at_position(position) || has_tile
			else:
				should_emit_sound = has_tile

	if should_emit_sound:
		emit_signal("play_sound_erase")

func _on_item_button_pressed(item_type: ItemButton.ItemType, button: ItemButton) -> void:
	var object_name: String = ""

	match item_type:
		ItemButton.ItemType.TILE:
			if "TileSingle" in button.name:
				switch_to_tilemap_mode_with_coords(Vector2i(0, 4))
			elif "TileSemiSolid" in button.name:
				switch_to_tilemap_mode_with_coords(Vector2i(1, 4))
			else:
				switch_to_tilemap_mode()
		ItemButton.ItemType.OBJECT:
			object_name = button.object_name
			if object_name == "":
				object_name = button.name.replace("ItemButton", "").to_lower()
			switch_to_objectmap_mode(object_name)
		ItemButton.ItemType.CLEAR_PIPE:
			object_name = button.object_name
			if object_name == "":
				object_name = button.name.replace("ItemButton", "").to_lower()
			switch_to_clear_pipe_mode(object_name)
		ItemButton.ItemType.ERASER:
			switch_to_eraser_mode()

	var item_groups: Array[Node] = get_tree().get_nodes_in_group("item_group")
	for node: Node in item_groups:
		if node is Control:
			var control: Control = node
			var timer: SceneTreeTimer = get_tree().create_timer(0.1)
			await timer.timeout
			control.visible = false

func reset_input_state() -> void:
	var input_handler: InputHandler = null
	if clear_pipe_draw and clear_pipe_draw.has_method("get_pipe_line_data"):
		var parent: Node = clear_pipe_draw.get_parent()
		if parent:
			for child: Node in parent.get_children():
				if child is InputHandler:
					input_handler = child
					break
	if not input_handler:
		for child: Node in get_tree().root.get_children():
			if child is InputHandler:
				input_handler = child
				break
	if input_handler:
		input_handler.is_clicking = false
