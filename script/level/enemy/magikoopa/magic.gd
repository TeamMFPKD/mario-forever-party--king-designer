extends CharacterBody2D

@onready var magic: CharacterBody2D = $"."
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var timer: Timer = $Timer
@onready var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
@export var speed: int = 300

var magic_particle_scene: PackedScene
var brick_scene: PackedScene
var spawn_items: Array


class SpawnItem:
	var scene: PackedScene
	var scene_name: String
	var probability: int

	func _init(sc: PackedScene, sn: String, prob: int) -> void:
		scene = sc
		scene_name = sn
		probability = prob


func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)
	if player:
		magic.velocity = (player.global_position - magic.global_position).normalized() * speed
	else:
		magic.queue_free()

	magic_particle_scene = load("res://object/level/enemy/magikoopa/magic_particle.tscn")
	brick_scene = load("res://object/level/block/brick_block.tscn")
	spawn_items = [
		SpawnItem.new(load("res://object/level/enemy/goomba.tscn") as PackedScene, "Goomba", 32),
		SpawnItem.new(load("res://object/level/block/coin.tscn") as PackedScene, "Coin", 8),
		SpawnItem.new(load("res://object/level/enemy/spiny.tscn") as PackedScene, "Spiny", 215),
		SpawnItem.new(load("res://object/level/bonus/mushroom.tscn") as PackedScene, "LifeMushroom", 1)
	]


func _physics_process(delta: float) -> void:
	magic.move_and_slide()
	sprite.rotation += 12 * delta


func _on_timer_timeout() -> void:
	var magic_particle: Node2D = magic_particle_scene.instantiate()
	magic_particle.position = magic.position
	add_sibling(magic_particle)


var all_body: Array = []
var seleceted_body: Node2D
var distance: float = 1000.0
var last: float = 1000.0


func _on_body_body_entered(body: Node2D) -> void:
	if body.is_in_group("brick"):
		all_body.append(body)

		(func() -> void:
			if all_body.size() == 1:
				seleceted_body = body
			else:
				for i: Node2D in all_body:
					distance = minf(magic.global_position.distance_to(i.global_position), distance)
					if last != distance:
						last = distance
						seleceted_body = body

			var scene_instantiated: Node2D = _select(spawn_items).instantiate()
			scene_instantiated.connect("tree_entered", func() -> void: scene_instantiated.global_position = seleceted_body.global_position)
			add_sibling(scene_instantiated)
			seleceted_body.queue_free()
			magic.queue_free()
		).call_deferred()

	else:
		magic.queue_free()


func _select(spawn_things: Array) -> PackedScene:
	if spawn_things.is_empty():
		push_error("SpawnItem spawn_things is empty!")
		return null

	var total_weight: int = 0
	var last_total_weight: int = 0
	var point: Array = []
	for i: SpawnItem in spawn_things:
		total_weight += i.probability
		point.append([i.scene, last_total_weight, total_weight])
		last_total_weight = total_weight
	var r: int = randi() % total_weight
	for j: Variant in point:
		if r >= j[1] and r < j[2]:
			return j[0]
	return