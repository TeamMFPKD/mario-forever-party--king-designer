extends Area2D

signal spring_bounced

func _ready() -> void:
	connect("body_entered", Callable(self, "on_body_entered"))

func _physics_process(_delta: float) -> void:
	var bodies = get_overlapping_bodies()
	for body in bodies:
		_check_bounce(body)

func _check_bounce(body: Node) -> void:
	if body.is_in_group("player"):
		var player_movement = body.get_meta("player_movement")
		if player_movement is PlayerMovement:
			player_movement.on_horizontal_spring_bounce(self)
			emit_signal("spring_bounced")
		emit_signal("spring_bounced")
	else:
		if body.has_meta("basic_movement"):
			var basic_movement = body.get_meta("basic_movement")
			if basic_movement is BasicMovement:
				basic_movement.on_horizontal_spring_bounce(self)
				emit_signal("spring_bounced")


func on_body_entered(body: Node) -> void:
	_check_bounce(body)
