extends StaticBody2D

enum EgdeType {
	LEFT,
	RIGHT,
}

@export var edge_type : EgdeType = EgdeType.LEFT

const LEVEL_EDGE_SHAPE_LEFT = preload("uid://qfpghfu13sn1")
const LEVEL_EDGE_SHAPE_RIGHT = preload("uid://dia0apwqxvmgd")

var level_camera : Camera2D

func _ready() -> void:
	level_camera = get_tree().get_first_node_in_group("level_camera") as Camera2D
	var collision_shape = $CollisionShape2D
	match edge_type:
		EgdeType.LEFT:
			collision_shape.shape = LEVEL_EDGE_SHAPE_LEFT
		EgdeType.RIGHT:
			collision_shape.shape = LEVEL_EDGE_SHAPE_RIGHT

func _physics_process(delta: float) -> void:
	match edge_type:
		EgdeType.LEFT:
			global_position.x = level_camera.limit_left
		EgdeType.RIGHT:
			global_position.x = level_camera.limit_right
