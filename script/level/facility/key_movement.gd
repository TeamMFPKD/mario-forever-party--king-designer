extends Node

class_name KeyMovement

signal play_sound_get
signal overflow

@export var path_to_key: NodePath = ".."
@export var path_to_ani: NodePath = "../AnimatedSprite2D"

@export var cursed: bool = false
@export var phanto_scene: PackedScene

var key: Node2D
var ani: AnimatedSprite2D
var past_player_status: Array = []

enum KeyState {
	IDLE,
	GOT,
	FOLLOWING,
}
var key_id: int = 0
var state: KeyState = KeyState.IDLE:
	set(value):
		state = value
		if value == KeyState.FOLLOWING:
			emit_signal("play_sound_get")
			if not is_in_group("key_following"):
				add_to_group("key_following")
			var following_keys = get_tree().get_nodes_in_group("key_following")
			key_id = following_keys.size()
			var player = get_tree().get_first_node_in_group("player") as Node2D
			if player:
				last_player_position = player.position
			if cursed:
				add_to_group("key_following_cursed")
				var got_cursed_keys = get_tree().get_nodes_in_group("key_following_cursed")
				var phantos = get_tree().get_nodes_in_group("phanto")
				if phantos.size() < got_cursed_keys.size():
					_create_phanto(player)
		if value == KeyState.GOT:
			if not try_follow():
				return
			add_to_group("key_following")
			if not _got_tween:
				_got_tween = create_tween()
				_got_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				_got_tween.tween_property(key, "position:y", key.position.y - 80.0, 0.4)
				_got_tween.finished.connect(func():
					state = KeyState.FOLLOWING
					_got_tween = null
				)
var time: float = 0.0

var track_frame: int = 0
var start_track_timer: int = 0
var start_track: bool = false

var dir: float = 1.0
var offset_x: float = 0.0

var _got_tween: Tween

const MAX_PAST_STATUS = 200
const TELEPORT_THRESHOLD = 64.0

var last_player_position: Vector2

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

	# 从问号砖生成
	if key.has_meta("spawned_by_block"):
		state = KeyState.GOT

func _on_body_entered(body: Node) -> void:
	if state != KeyState.IDLE:
		return
	if body.is_in_group("player"):
		if not try_follow():
			return
		state = KeyState.FOLLOWING
	

func try_to_get_key(body: Node2D = null) -> void:
	if not body:
		body = get_tree().get_first_node_in_group("player") as Node2D
	if not body:
		push_error("KeyMovement: No player found to get the key!")
		return

func try_follow() -> bool:
	var locked_doors = round(get_tree().get_nodes_in_group("door_locked").size() / 2.0)
	var got_keys = get_tree().get_nodes_in_group("key_following").size()
	if got_keys >= locked_doors:
		emit_signal("overflow")
		return false
	return true

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
	if not player:
		return

	var player_movement = player.get_meta("player_movement") as PlayerMovement
	if player_movement.speed_x != 0.0:
		dir = sign(player_movement.speed_x)
	var target_offset = -(16.0 + (key_id - 1) * 8.0) * dir

	var teleported = last_player_position.distance_to(player.position) > TELEPORT_THRESHOLD
	if teleported:
		var entry = {"position": player.position, "is_on_floor": player.is_on_floor()}
		past_player_status.fill(entry)
		key.position = player.position + Vector2(0, -8)
		track_frame = 0
		start_track_timer = 0
		start_track = false
		key.reset_physics_interpolation()

	last_player_position = player.position

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

	if track_frame > 5 + (key_id - 1) * 5:
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
			key.position.y -= abs(sin(time * 5.0 + (key_id - 1) * 0.5) * 8.0)

	offset_x += (target_offset - offset_x) * 0.02
	key.position.x += offset_x

func _create_phanto(body: Node) -> void:
	var phanto = phanto_scene.instantiate() as Node2D
	var spawn_vector = body.position - key.position
	var angle = Vector2.ZERO.angle_to(spawn_vector)
	# Phanto will not spawn at the same position as the player, but a bit away
	angle -= PI / 4.0
	spawn_vector = Vector2.from_angle(angle)
	var spawn_position = spawn_vector * (640.0 + 64.0)
	phanto.position = key.position + spawn_position
	var fc = func():
		key.add_sibling(phanto)
	fc.call_deferred()
