extends Node

@export var bottom_bar: Control
@export var sub_viewport_container: Control
@export var game_room_size: Control
@export var pop_speed: float = 300.0
@export var trigger_distance: float = 80.0

var _origin_offset_top: float
var _origin_offset_bottom: float
var _target_offset: float
var _should_pop: bool = false

@export var group_panels: Array[Control]

func _ready() -> void:
	_origin_offset_top = bottom_bar.offset_top
	_origin_offset_bottom = bottom_bar.offset_bottom
	_target_offset = 0.0
	game_room_size.resized.connect(_on_game_room_size_resized)
	_on_game_room_size_resized()

func _on_game_room_size_resized() -> void:
	# game_room_size变化后，用实际全局坐标判断是否需要pop
	var bar_global_top = bottom_bar.global_position.y
	var viewport_global_bottom = sub_viewport_container.global_position.y + sub_viewport_container.size.y
	_should_pop = bar_global_top < viewport_global_bottom

func _process(delta: float) -> void:
	_update_target()
	_move_toward_target(delta)

func _update_target() -> void:
	if not _should_pop:
		_target_offset = 0.0
		return

	var scale_y = 1080.0 / bottom_bar.get_parent_control().size.y
	var mouse_local_y = bottom_bar.get_parent_control().get_local_mouse_position().y * scale_y
	#var bar_top_y = 1080.0 + bottom_bar.offset_top
	var viewport_bottom = sub_viewport_container.offset_bottom

	if mouse_local_y >= viewport_bottom - trigger_distance and are_all_buttons_invisible():
		_target_offset = viewport_bottom - 1080.0 - _origin_offset_top + 32.0
	else:
		_target_offset = 0.0

func _move_toward_target(delta: float) -> void:
	var current_offset = bottom_bar.offset_top - _origin_offset_top
	if is_equal_approx(current_offset, _target_offset):
		return
	var new_offset = move_toward(current_offset, _target_offset, pop_speed * delta)
	bottom_bar.offset_top = _origin_offset_top + new_offset
	bottom_bar.offset_bottom = _origin_offset_bottom + new_offset

func are_all_buttons_invisible() -> bool:
	for panel in group_panels:
		if panel.visible:
			return false
	return true
