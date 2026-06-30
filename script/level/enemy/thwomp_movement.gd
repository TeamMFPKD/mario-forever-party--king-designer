extends BasicMovement

signal play_sound_stun

@export var screen_notifier: VisibleOnScreenNotifier2D
@export var safe_distance_x: float = 96.0
@export var land_time: int = 72
@export var thwomp_gravity: float = 2000.0
@export var rising_speed: float = -60.0

var _origin_position_y: float
var land_timer: int

var is_ready: bool = false

enum ThwompState {
	IDLE,
	FALL,
	LAND,
	RISE,
}

var state = ThwompState.IDLE

func _ready():
	super._ready()
	_origin_position_y = move_object.position.y
	await screen_notifier.ready
	for i in range(3):
		await get_tree().physics_frame
	is_ready = true
	#print("is_ready: ", is_ready)

func _physics_process(delta):
	super._physics_process(delta)
	#print("state: ", state)
	if not is_ready:
		#print("is_ready: ", is_ready)
		return
	if is_in_pipe:
		if state == ThwompState.LAND:
			state = ThwompState.FALL
		return
	match state:
		ThwompState.IDLE:
			if not screen_notifier.is_on_screen():
				return
			move_object.force_update_transform()
			if player.position.x < move_object.position.x + safe_distance_x \
			and player.position.x > move_object.position.x - safe_distance_x:
				#print("thwomp is in FALL status")
				state = ThwompState.FALL
		ThwompState.FALL:
			gravity = thwomp_gravity
			if move_object.is_on_floor():
				gravity = 0.0
				speed_y = 0.0
				land_timer = 0
				emit_signal("play_sound_stun")
				state = ThwompState.LAND
		ThwompState.LAND:
			#print("land_timer: ", land_timer)
			if land_timer < land_time:
				land_timer += 1
				return
			land_timer = 0
			move_object.position.y -= 1.0
			state = ThwompState.RISE
		ThwompState.RISE:
			speed_y = rising_speed
			if move_object.position.y <= _origin_position_y:
				move_object.position.y = _origin_position_y
				speed_y = 0.0
				state = ThwompState.IDLE
			if move_object.is_on_ceiling():
				_origin_position_y = move_object.position.y
				speed_y = 0.0
				state = ThwompState.IDLE

func _on_bump_block():
	gravity = 0.0
	speed_y = 0.0
	land_timer = 0
	emit_signal("play_sound_stun")
	state = ThwompState.LAND

func exit_pipe() -> void:
	match pipe_moving_dir:
		PipeMoveDirection.UP:
			state = ThwompState.RISE
			move_object.position.y -= 48.0
			_origin_position_y = move_object.position.y
		PipeMoveDirection.RIGHT:
			previous_speed_x = abs(previous_speed_x)
	super.exit_pipe()