extends AnimatableBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var solid: CollisionShape2D = $PhysicsCollision
@onready var area2d: Area2D = $Area2D
@onready var enemy_kill_area: Area2D = $EnemyKill

@export_enum("Blue", "Red") var mode: int

var visibility: bool
var flag_entered: bool = false
var flag_exited: bool = false

var player : Node2D


func _ready() -> void:
	match mode:
		0:
			visibility = false
		1:
			visibility = true
	sprite.play("normal" if visibility else "invisible")
	solid.set_deferred(&"disabled", not visibility)
	player = get_tree().get_first_node_in_group("player")


func _on_area_2d_body_entered(_body: Node2D) -> void:
	flag_exited = false
	if flag_entered == false:
		flag_entered = true
		_switch_status()


func _on_area_2d_body_exited(_body: Node2D) -> void:
	flag_entered = false
	if flag_exited == false:
		flag_exited = true
		_switch_status()
		
		
func _switch_status():
	visibility = not visibility
	var target_anim = &"visible" if visibility else &"invisible"
	if sprite.animation != target_anim:
		sprite.play(target_anim)
	solid.set_deferred(&"disabled", not visibility)


func _on_animated_sprite_2d_animation_finished() -> void:
	if visibility == true and sprite.animation == &"visible":
		sprite.play("normal")