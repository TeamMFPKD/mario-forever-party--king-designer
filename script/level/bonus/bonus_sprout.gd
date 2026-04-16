extends CharacterBody2D

class_name BonusSprout

@export var path_to_bonus : NodePath = ".."
@export var path_to_collision_shape : NodePath = "../CollisionShape2D"
@export var sprout_speed = 50.0
@export var path_to_basic_movement : NodePath = "../BasicMovement"

var bonus : CharacterBody2D
var collision_shape : CollisionShape2D
var in_wall_cast : ShapeCast2D
var basic_movement : BasicMovement

var is_sprout : bool = false
var origin_bonus_collision_layer : int
var origin_bonus_collision_mask : int

var initialize : bool = false

func _ready() -> void:
	bonus = get_node(path_to_bonus)
	if bonus == null:
		push_error("Bonus node not found at path: " + str(path_to_bonus))
		return
		
	origin_bonus_collision_layer = bonus.collision_layer
	origin_bonus_collision_mask = bonus.collision_mask
	bonus.collision_layer = 0
	bonus.collision_mask = 0
	bonus.process_mode = ProcessMode.PROCESS_MODE_DISABLED
	
	collision_shape = get_node(path_to_collision_shape)
	if collision_shape == null:
		push_error("CollisionShape2D node not found at path: " + str(path_to_collision_shape))
		return
		
	in_wall_cast = get_node("ShapeCast2D")
	if in_wall_cast == null:
		push_error("ShapeCast2D node not found")
		return
		
	if collision_shape.shape == null:
		push_error("CollisionShape2D has no shape assigned")
		return
		
	in_wall_cast.shape = collision_shape.shape
	
	basic_movement = get_node(path_to_basic_movement)
	if basic_movement:
		basic_movement.process_mode = ProcessMode.PROCESS_MODE_DISABLED
	if bonus.has_meta("sprout_down"):
		print("Sprout down")
		sprout_speed = -sprout_speed

	# 神神秘秘 CharacterBody2D
	await get_tree().physics_frame
	await get_tree().physics_frame
	initialize = true
	
	bonus.process_mode = ProcessMode.PROCESS_MODE_INHERIT
	basic_movement.process_mode = ProcessMode.PROCESS_MODE_INHERIT
	collision_recover()

	if not is_overlap():
		is_sprout = true
		bonus.collision_layer = origin_bonus_collision_layer
		return
	bonus.process_mode = ProcessMode.PROCESS_MODE_DISABLED
	#for child in bonus.get_children():
		#if child == self:
			#continue
		#child.process_mode = ProcessMode.PROCESS_MODE_DISABLED
	basic_movement.process_mode = ProcessMode.PROCESS_MODE_DISABLED

func _physics_process(delta: float) -> void:
	if not initialize:
		return
	if not is_sprout and is_overlap():
		bonus.position.y -= sprout_speed * delta
	else:
		bonus.process_mode = ProcessMode.PROCESS_MODE_INHERIT
		#for child in bonus.get_children():
			#if child == self:
				#continue
			#child.process_mode = ProcessMode.PROCESS_MODE_INHERIT
		if basic_movement:
			basic_movement.process_mode = ProcessMode.PROCESS_MODE_INHERIT
			if not is_sprout:
				basic_movement.set_movement_direction()
		is_sprout = true
		bonus.collision_layer = origin_bonus_collision_layer
	
func is_overlap() -> bool:
	#print(ShapeCastQuery.shape_query(bonus, in_wall_cast))
	if not in_wall_cast:
		push_error("[%s] in_wall_cast is not set" % bonus.name)
		return false
	return ShapeCastQuery.shape_query(bonus, in_wall_cast).size() > 0

func collision_recover() -> void:
	for i in range(5):
		#print("bonus waiting: %s frame" % i)
		await get_tree().physics_frame
	bonus.collision_layer = origin_bonus_collision_layer
	bonus.collision_mask = origin_bonus_collision_mask
