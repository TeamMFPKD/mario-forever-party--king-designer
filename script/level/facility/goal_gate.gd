extends Area2D

signal goal_reached

@export var bar : Sprite2D
@export var smoke_scene : PackedScene

var smoke : Node2D

var is_passed : bool = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and !is_passed:
		is_passed = true

		smoke = smoke_scene.instantiate() as Node2D
		smoke.position.x = position.x - 4
		smoke.position.y = position.y + bar.position.y
		add_sibling(smoke)

		bar.queue_free()

		get_tree().paused = true

		print("goal reached")
		emit_signal("goal_reached")
