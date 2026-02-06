extends CharacterBody2D

class_name BonusSprout

@export var path_to_bonus : NodePath = ".."
@export var path_to_collision_shape : NodePath = "../CollisionShape2D"
@export var sprout_speed = 50.0
@export var path_to_basic_movement : NodePath = "../BasicMovement"

var bonus : Node2D
var collision_shape : CollisionShape2D
var in_wall_cast : ShapeCast2D
var basic_movement : BasicMovement

var is_sprout : bool = false

func _ready() -> void:
	bonus = get_node(path_to_bonus)
	collision_shape = get_node(path_to_collision_shape)
	in_wall_cast = get_node("ShapeCast2D")
	in_wall_cast.shape = collision_shape.shape
	if not is_overlap():
		is_sprout = true
		return
	bonus.process_mode = ProcessMode.PROCESS_MODE_DISABLED
	#for child in bonus.get_children():
		#if child == self:
			#continue
		#child.process_mode = ProcessMode.PROCESS_MODE_DISABLED
	basic_movement = get_node_or_null(path_to_basic_movement)
	if basic_movement:
		basic_movement.process_mode = ProcessMode.PROCESS_MODE_DISABLED

func _physics_process(delta: float) -> void:
	if not is_sprout and is_overlap():
		print("woc tai")
		bonus.position.y -= sprout_speed * delta
	else:
		bonus.process_mode = ProcessMode.PROCESS_MODE_INHERIT
		#for child in bonus.get_children():
			#if child == self:
				#continue
			#child.process_mode = ProcessMode.PROCESS_MODE_INHERIT
		if basic_movement:
			basic_movement.process_mode = ProcessMode.PROCESS_MODE_INHERIT
		is_sprout = true
	
func is_overlap() -> bool:
	#print(ShapeCastQuery.shape_query(bonus, in_wall_cast))
	return ShapeCastQuery.shape_query(bonus, in_wall_cast).size() > 0
