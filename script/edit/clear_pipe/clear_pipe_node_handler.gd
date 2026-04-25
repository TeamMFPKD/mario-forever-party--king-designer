extends Node2D

signal handler_pressed(handler: Node2D)
signal handler_released(handler: Node2D)

var is_held: bool = false
var is_tail: bool = false
var line_index: int = -1
var can_draw_right: bool = true
var can_draw_left: bool = true
var can_draw_up: bool = true
var can_draw_down: bool = true

var _original_shape: Shape2D = null

func _ready() -> void:
	var touch_screen_button = get_node_or_null("TouchScreenButton")
	if touch_screen_button:
		_original_shape = touch_screen_button.shape
		touch_screen_button.pressed.connect(_on_pressed)
		touch_screen_button.released.connect(_on_released)
	_apply_tail_state()
	hide_arrows()
	update_handler_color()

func _event_to_world(event: InputEvent) -> Vector2:
	var viewport = get_viewport()
	if viewport:
		return viewport.get_canvas_transform().affine_inverse() * event.position
	return event.position

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return

	var pressed: bool = event.pressed

	var world_pos = _event_to_world(event)
	var diff = world_pos - global_position
	if abs(diff.x) <= 20.0 and abs(diff.y) <= 20.0:
		if pressed and not is_held:
			is_held = true
			handler_pressed.emit(self)
			update_arrow_visibility()
			update_handler_color()
			get_viewport().set_input_as_handled()
		elif not pressed and is_held:
			is_held = false
			handler_released.emit(self)
			hide_arrows()
			update_handler_color()
			get_viewport().set_input_as_handled()

func _is_point_in_handler(pos: Vector2) -> bool:
	return abs(pos.x) <= 20.0 and abs(pos.y) <= 20.0

func _on_pressed() -> void:
	is_held = true
	handler_pressed.emit(self)
	update_arrow_visibility()
	update_handler_color()

func _on_released() -> void:
	is_held = false
	handler_released.emit(self)
	hide_arrows()
	update_handler_color()

func set_tail(value: bool) -> void:
	is_tail = value
	_apply_tail_state()
	update_handler_color()

func set_held(value: bool) -> void:
	is_held = value
	if is_held:
		update_arrow_visibility()
	else:
		hide_arrows()
	update_handler_color()

func _apply_tail_state() -> void:
	var touch_screen_button = get_node_or_null("TouchScreenButton")
	if touch_screen_button:
		touch_screen_button.visible = true
		touch_screen_button.shape = _original_shape

func update_handler_color() -> void:
	var edit_handler = get_node_or_null("EditObjectHandler")
	if not edit_handler:
		return
	
	if is_held:
		edit_handler.modulate = Color(1, 0.5, 0, 1)
	else:
		edit_handler.modulate = Color.WHITE

func hide_arrows() -> void:
	var arrow_right = get_node_or_null("EditPipeArrowRight")
	var arrow_left = get_node_or_null("EditPipeArrowLeft")
	var arrow_up = get_node_or_null("EditPipeArrowUp")
	var arrow_down = get_node_or_null("EditPipeArrowDown")
	
	if arrow_right:
		arrow_right.visible = false
	if arrow_left:
		arrow_left.visible = false
	if arrow_up:
		arrow_up.visible = false
	if arrow_down:
		arrow_down.visible = false

func update_arrow_visibility() -> void:
	if not is_held:
		hide_arrows()
		return
	
	var arrow_right = get_node_or_null("EditPipeArrowRight")
	var arrow_left = get_node_or_null("EditPipeArrowLeft")
	var arrow_up = get_node_or_null("EditPipeArrowUp")
	var arrow_down = get_node_or_null("EditPipeArrowDown")
	
	if not arrow_right or not arrow_left or not arrow_up or not arrow_down:
		return
	
	arrow_right.visible = can_draw_right
	arrow_left.visible = can_draw_left
	arrow_up.visible = can_draw_up
	arrow_down.visible = can_draw_down

func set_draw_directions(right: bool, left: bool, up: bool, down: bool) -> void:
	can_draw_right = right
	can_draw_left = left
	can_draw_up = up
	can_draw_down = down
	if is_held:
		update_arrow_visibility()

func get_draw_directions() -> Dictionary:
	return {
		"right": can_draw_right,
		"left": can_draw_left,
		"up": can_draw_up,
		"down": can_draw_down
	}
