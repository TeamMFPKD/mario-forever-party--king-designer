extends Node

class_name OutOfBoundsQueueFree

# 出屏销毁
@export_group("OutOfScreen")
@export var out_of_screen_detection: bool = false
@export var screen_up: bool = false
@export var screen_up_offset: float = 99999.0
@export var screen_down: bool = true
@export var screen_down_offset: float = 32.0
@export var screen_left: bool = true
@export var screen_left_offset: float = 16.0
@export var screen_right: bool = true
@export var screen_right_offset: float = 16.0

# 出房间销毁
@export_group("OutOfRoom")
@export var out_of_room_detection: bool = true
@export var room_up: bool = false
@export var room_up_offset: float = 99999.0
@export var room_down: bool = true
@export var room_down_offset: float = 32.0
@export var room_left: bool = true
@export var room_left_offset: float = 16.0
@export var room_right: bool = true
@export var room_right_offset: float = 16.0

var _room_bounds: Rect2
var _target: Node2D
var level_camera: Camera2D

func _ready():
	_target = get_parent() as Node2D
	level_camera = get_tree().get_first_node_in_group("level_camera") as Camera2D
	_room_bounds = Rect2(Vector2(level_camera.limit_left, level_camera.limit_top), Vector2(level_camera.limit_right - level_camera.limit_left, level_camera.limit_bottom - level_camera.limit_top))

func _physics_process(delta):
	var destroy: bool = false
	
	# 出屏检测
	if out_of_screen_detection:
		var screen_rect = ScreenUtils.get_screen_rect(_target)
		
		if screen_up and _target.position.y < screen_rect.position.y - screen_up_offset:
			destroy = true
		if screen_down and _target.position.y > screen_rect.end.y + screen_down_offset:
			destroy = true
		if screen_left and _target.position.x < screen_rect.position.x - screen_left_offset:
			destroy = true
		if screen_right and _target.position.x > screen_rect.end.x + screen_right_offset:
			destroy = true

	# 出房间检测
	if out_of_room_detection:
		if room_up and _target.position.y < _room_bounds.position.y - room_up_offset:
			destroy = true
		if room_down and _target.position.y > _room_bounds.end.y + room_down_offset:
			destroy = true
		if room_left and _target.position.x < _room_bounds.position.x - room_left_offset:
			destroy = true
		if room_right and _target.position.x > _room_bounds.end.x + room_right_offset:
			destroy = true

	if destroy:
		_target.queue_free()
