extends Node
## Controller that moves a parent Node2D towards a target (Mario).
## Attach this to a child of the object you want to move.
## Target priority: exported path > "player" group.

# The object we actually move (its parent)
@export var path_to_move_obj: NodePath = ".."
# (Optional) direct path to the target; overrides group search
@export var path_to_target: NodePath

@export var tracking_enabled: bool = true
@export var max_speed: Vector2 = Vector2(2.0, 2.0)    # max_vx, max_vy
@export var acceleration: Vector2 = Vector2(0.2, 0.2)  # acc_x, acc_y
@export var deceleration_speed: float = 4.8            # the 'Z' value

var move_object: Node2D   # the Phanto
var target_node: Node2D   # the Mario (or player group node)

# Sub‑pixel position (like Alterable Values X/Y)
var pos: Vector2
var velocity: Vector2 = Vector2.ZERO
var target_pos: Vector2
var frame: int = 0

# Blinking logic (Alterable Values AA, AB)
var _aa: int = 0  # Counter for blink cycle
var _is_blinking: bool = false

## Start the blinking sequence. Call this to trigger the flash effect.
func start_blink() -> void:
	_aa = 0
	_is_blinking = true

## Stops the blinking and resets the shader to normal.
func stop_blink() -> void:
	_is_blinking = false
	_aa = 0
	_set_shader_enabled(false)

func _update_blink() -> void:
	if not _is_blinking:
		return

	# AA < 14: blinking cycle
	if _aa < 14:
		_aa += 1
		var ab: int = _aa % 5  # AB = AA mod 5

		# Set effect to None first (enabled = false)
		_set_shader_enabled(false)

		# If AB < 2, set effect to Inverted (enabled = true)
		if ab < 2:
			_set_shader_enabled(true)
	# AA = 14: create effect and stop blinking
	elif _aa == 14:
		_is_blinking = false
		_aa = 0
		_set_shader_enabled(false)

func _set_shader_enabled(enabled: bool) -> void:
	var sprite: AnimatedSprite2D = move_object.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.material:
		var mat: ShaderMaterial = sprite.material as ShaderMaterial
		mat.set_shader_parameter("enabled", enabled)

func _create_effect() -> void:
	var effect_node: Node = move_object.get_node("PhantoEffect")
	if effect_node and effect_node.has_method("trigger_effect"):
		effect_node.trigger_effect()


func _ready() -> void:
	move_object = get_node_or_null(path_to_move_obj) as Node2D
	if not move_object:
		push_error("Move object (parent) not found.")
		return

	# Target resolution: explicit path first, then "player" group
	if not path_to_target.is_empty():
		target_node = get_node_or_null(path_to_target) as Node2D
	else:
		target_node = get_tree().get_first_node_in_group("player") as Node2D

	# Initial position from the actual object
	pos = move_object.global_position
	target_pos = pos


func _physics_process(_delta: float) -> void:
	if not move_object:
		return

	_update_blink()

	frame += 1
	_update_target_position()

	# Tracking logic runs every 4 frames
	if tracking_enabled and frame % 4 == 0:
		apply_tracking()
	# Deceleration runs every 2 frames when not tracking
	elif not tracking_enabled and frame % 2 == 0:
		apply_deceleration()

	# Apply velocity every frame
	pos += velocity
	move_object.global_position = pos
	
	_create_effect()


func _update_target_position() -> void:
	if target_node:
		target_pos = target_node.global_position


func apply_tracking() -> void:
	velocity.x = _compute_accelerated_axis(
		velocity.x,
		target_pos.x - pos.x,
		max_speed.x,
		acceleration.x
	)
	velocity.y = _compute_accelerated_axis(
		velocity.y,
		target_pos.y - pos.y,
		max_speed.y,
		acceleration.y
	)


func _compute_accelerated_axis(current_vel: float, distance: float, max_spd: float, acc: float) -> float:
	# Determine directional max speed and acceleration sign
	var max_v: float = -max_spd if distance <= 0.0 else max_spd
	var accel: float = -acc if distance <= 0.0 else acc
	var new_vel: float = current_vel

	# Accelerate if below max or moving opposite direction
	if abs(new_vel) < abs(max_v) or new_vel * max_v < 0:
		new_vel += accel
		# Clamp to the directional max
		if max_v > 0:
			new_vel = min(new_vel, max_v)
		elif max_v < 0:
			new_vel = max(new_vel, max_v)
	return new_vel


func apply_deceleration() -> void:
	var step: float = 1.0 / deceleration_speed
	velocity.x = _decelerate_axis(velocity.x, step)
	velocity.y = _decelerate_axis(velocity.y, step)


func _decelerate_axis(val: float, step: float) -> float:
	if val > 0.0:
		val -= step
		if val < 0.0:
			return 0.0
	elif val < 0.0:
		val += step
		if val > 0.0:
			return 0.0
	return val


# 只是测试用，但是感觉很有趣，保留也不错（
"""
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_jump"):
		start_blink()
"""