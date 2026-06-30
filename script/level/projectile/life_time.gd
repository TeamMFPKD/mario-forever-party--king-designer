extends Node

@export var life_time: int = 102
@export var blink_time: int = 30

var timer: int = 0
var is_blinking: bool = false
var parent: Node


func _ready() -> void:
	parent = get_parent()


func _physics_process(_delta) -> void:
	timer += 1
	if timer >= life_time - blink_time and not is_blinking:
		blink()
	if timer >= life_time:
		parent.queue_free()
	

func blink() -> void:
	is_blinking = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	parent.visible = not parent.visible
	is_blinking = false
