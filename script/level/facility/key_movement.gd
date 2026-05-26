extends Node

signal play_sound_get

@export var path_to_key: NodePath = ".."
@export var path_to_ani: NodePath = "../AnimatedSprite2D"

var key: Node2D
var ani: AnimatedSprite2D
var past_player_status: Array = []

enum KeyState {
	IDLE,
	GOT,
	FOLLOWING,
}
var state: KeyState = KeyState.IDLE:
	set(value):
		state = value
		if value == KeyState.FOLLOWING:
			emit_signal("play_sound_get")
var time: float = 0.0

var track_frame: int = 0
var start_track_timer: int = 0
var start_track: bool = false

var dir: float = 1.0
var offset_x: float = 0.0

const MAX_PAST_STATUS = 200

func _ready() -> void:
	key = get_node(path_to_key) as Node2D
	key.body_entered.connect(_on_body_entered)
	ani = get_node(path_to_ani) as AnimatedSprite2D

	past_player_status.resize(MAX_PAST_STATUS)
	past_player_status.fill(
		{
			"position": Vector2.ZERO,
			"is_on_floor": true,
		}
	)

func _on_body_entered(body: Node) -> void:
	if state != KeyState.IDLE:
		return
	if body.is_in_group("player"):
		state = KeyState.FOLLOWING

func _physics_process(delta: float) -> void:
	if not key or not ani:
		return

	time += delta * 2.3

	match state:
		KeyState.IDLE:
			ani.position.y = sin(time) * 4.0

		KeyState.GOT:
			pass

		KeyState.FOLLOWING:
			_follow_player()

func _follow_player() -> void:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	var player_movement = player.get_meta("player_movement") as PlayerMovement
	if player_movement.speed_x != 0.0:
		dir = sign(player_movement.speed_x)
	var target_offset = -16.0 * dir

	if not player:
		return

	if track_frame < MAX_PAST_STATUS - 1:
		track_frame += 1
	else:
		track_frame = 0
	past_player_status[track_frame] = (
		{
			"position": player.position,
			"is_on_floor": player.is_on_floor(),
		}
	)

	if track_frame > 7:
		start_track = true
	
	if not start_track:
		return

	if start_track_timer < MAX_PAST_STATUS - 1:
		start_track_timer += 1
	else:
		start_track_timer = 0

	key.position = past_player_status[start_track_timer]["position"]
	key.position += Vector2(0, -8)

	var is_previous_x_same: bool = false
	if start_track_timer > 0:
		is_previous_x_same = past_player_status[start_track_timer - 1]["position"].x == past_player_status[start_track_timer]["position"].x
	else:
		# When start_track_timer is 0, compare with the last element in the array
		is_previous_x_same = past_player_status[MAX_PAST_STATUS - 1]["position"].x == past_player_status[start_track_timer]["position"].x
	if past_player_status[start_track_timer]["is_on_floor"]:
		if not is_previous_x_same:
			key.position.y -= abs(sin(time * 5.0) * 8.0)

	offset_x += (target_offset - offset_x) * 0.1
	key.position.x += offset_x
