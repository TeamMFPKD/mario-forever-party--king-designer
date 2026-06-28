extends StaticBody2D

enum EgdeType {
	LEFT,
	RIGHT,
}

@export var edge_type : EgdeType = EgdeType.LEFT

const LEVEL_EDGE_SHAPE_LEFT = preload("uid://qfpghfu13sn1")
const LEVEL_EDGE_SHAPE_RIGHT = preload("uid://dia0apwqxvmgd")

var level_camera : Camera2D
var origin_collision_layer
var player_movement : PlayerMovement
var edge_shape : WorldBoundaryShape2D

const LEFT_NORMALS := [
	Vector2(1, 0),
	Vector2(0, -1),
	Vector2(-1, 0),
	Vector2(0, 1),
]

const RIGHT_NORMALS := [
	Vector2(-1, 0),
	Vector2(0, 1),
	Vector2(1, 0),
	Vector2(0, -1),
]

func _ready() -> void:
	level_camera = get_tree().get_first_node_in_group("level_camera") as Camera2D
	player_movement = get_node("../../PlayerMediator/PlayerMovement") as PlayerMovement
	origin_collision_layer = collision_layer
	collision_layer = 0
	var cs = $CollisionShape2D
	match edge_type:
		EgdeType.LEFT:
			cs.shape = LEVEL_EDGE_SHAPE_LEFT.duplicate()
		EgdeType.RIGHT:
			cs.shape = LEVEL_EDGE_SHAPE_RIGHT.duplicate()
			global_position.x = level_camera.limit_right
	edge_shape = cs.shape
	var fc = func():
		collision_layer = origin_collision_layer
	fc.call_deferred()

func _physics_process(_delta: float) -> void:
	var cam = level_camera
	var grav = wrapi(int(round(-player_movement.target_gravity / 90.0)), 0, 4)
	match edge_type:
		EgdeType.LEFT:
			match grav:
				0: global_position.x = cam.limit_left
				1: global_position.y = cam.limit_bottom
				2: global_position.x = cam.limit_right
				3: global_position.y = cam.limit_top
			edge_shape.normal = LEFT_NORMALS[grav]
		EgdeType.RIGHT:
			match grav:
				0: global_position.x = cam.limit_right
				1: global_position.y = cam.limit_top
				2: global_position.x = cam.limit_left
				3: global_position.y = cam.limit_bottom
			edge_shape.normal = RIGHT_NORMALS[grav]
