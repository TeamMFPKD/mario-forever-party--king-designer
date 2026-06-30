extends StaticBody2D

var origin_pos_y: float
var player: Node2D
var print_counter: int = 0

func _ready() -> void:
	origin_pos_y = position.y
	var fc = func():
		player = get_tree().get_first_node_in_group("player") as Node2D
	fc.call_deferred()

func _physics_process(_delta: float) -> void:
	if not player:
		if print_counter < 10:
			print_counter += 1
			push_error("[sealer.gd] player not found")
		return
	position.y = min(origin_pos_y, player.position.y)
