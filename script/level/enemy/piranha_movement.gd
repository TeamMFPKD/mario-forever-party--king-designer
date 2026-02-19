extends Node

class_name PiranhaMovement

signal shoot

@export var path_to_piranha : NodePath = ".."
var piranha : Node2D

enum MoveDirection {
	UP,
	DOWN,
}

@export var move_direction : MoveDirection = MoveDirection.UP

enum State {
	IN,
	GOING_OUT,
	OUT,
	GOING_IN,
}

var state : State = State.IN

@export var speed : float = 60.0
@export var shy_distance : float = 64.0
@export var wait_time : int = 84

@export var fire : bool

var wait_timer : int = 0
var player : Node2D
var out_position_y : float
var in_position_y : float

const PIRANHA_MOVE_DISTANCE : float = 64.0

func _ready() -> void:
	piranha = get_node(path_to_piranha)
	var fc = func():
		player = get_tree().get_first_node_in_group("player") as Node2D
	fc.call_deferred()
	out_position_y = piranha.position.y
	match move_direction:
		MoveDirection.UP:
			piranha.position.y += PIRANHA_MOVE_DISTANCE
		MoveDirection.DOWN:
			piranha.position.y -= PIRANHA_MOVE_DISTANCE
	in_position_y = piranha.position.y

func _physics_process(delta: float) -> void:
	var is_shy : bool
	if player.position.x < piranha.position.x + shy_distance \
	and player.position.x > piranha.position.x - shy_distance:
		is_shy = true
	else:
		is_shy = false
		
	match state:
		State.IN:
			if not is_shy:
				state = State.GOING_OUT
		State.GOING_OUT:
			piranha.position.y = move_toward(piranha.position.y, out_position_y, speed * delta)
			if piranha.position.y == out_position_y:
				state = State.OUT
		State.OUT:
			wait_timer += 1
			if wait_timer == int(wait_time / 2.0) and fire:
				emit_signal("shoot")
			if wait_timer > wait_time:
				wait_timer = 0
				state = State.GOING_IN
		State.GOING_IN:
			piranha.position.y = move_toward(piranha.position.y, in_position_y, speed * delta)
			if piranha.position.y == in_position_y:
				wait_timer += 1
				if wait_timer > wait_time:
					wait_timer = 0
					state = State.IN
