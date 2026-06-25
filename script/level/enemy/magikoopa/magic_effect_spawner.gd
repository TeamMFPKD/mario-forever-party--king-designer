extends Node

var magic_particle_scene: PackedScene = load("res://object/level/enemy/magikoopa/magic_particle.tscn")
var timer: Timer


func _ready():
	timer = Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)


func _on_timer_timeout():
	var magic_particle = magic_particle_scene.instantiate()
	magic_particle.position = owner.position
	owner.add_sibling(magic_particle)
