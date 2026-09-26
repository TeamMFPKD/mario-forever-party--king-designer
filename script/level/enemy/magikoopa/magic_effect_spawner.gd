extends Node

var magic_particle_scene: PackedScene = load("res://object/level/enemy/magikoopa/magic_particle.tscn")
var timer: Timer


func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)


func _on_timer_timeout() -> void:
	var magic_particle: Node2D = magic_particle_scene.instantiate()
	var owner_node: Node2D = owner
	magic_particle.position = owner_node.position
	owner_node.add_sibling(magic_particle)