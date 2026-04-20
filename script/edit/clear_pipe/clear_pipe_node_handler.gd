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

func _on_pressed() -> void:
	is_held = true
	handler_pressed.emit(self)
	update_arrow_visibility()

func _on_released() -> void:
	is_held = false
	handler_released.emit(self)
	hide_arrows()

func set_tail(value: bool) -> void:
	is_tail = value
	_apply_tail_state()

func set_held(value: bool) -> void:
	is_held = value
	if is_held:
		update_arrow_visibility()
	else:
		hide_arrows()

func _apply_tail_state() -> void:
	var touch_screen_button = get_node_or_null("TouchScreenButton")
	if touch_screen_button:
		touch_screen_button.visible = is_tail
		touch_screen_button.shape = _original_shape if is_tail else null

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
	if not is_tail or not is_held:
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
