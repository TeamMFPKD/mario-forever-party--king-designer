extends Area2D


class SpawnItem:
	var scene: PackedScene
	var scene_name: String
	var probability: int

	func _init(sc: PackedScene, sn: String, prob: int) -> void:
		scene = sc
		scene_name = sn
		probability = prob


@onready var magic: CharacterBody2D = owner

var brick_scene: PackedScene = load("res://object/level/block/brick_block.tscn")
var spawn_items: Array = [
	SpawnItem.new(load("res://object/level/enemy/goomba.tscn") as PackedScene, "Goomba", 32),
	SpawnItem.new(load("res://object/level/block/coin.tscn") as PackedScene, "Coin", 8),
	SpawnItem.new(load("res://object/level/enemy/spiny.tscn") as PackedScene, "Spiny", 215),
	SpawnItem.new(load("res://object/level/bonus/mushroom.tscn") as PackedScene, "LifeMushroom", 1)
]

var is_used: bool = false

func _on_body_body_entered(body: Node2D) -> void:
	var interaction_node: Node = body.get_meta("interaction_with_block") if body.has_meta("interaction_with_block") else null
	if interaction_node == null:
		return
	if interaction_node.has_meta("is_brick"):
		if is_used:
			return
		is_used = true
		(func() -> void:
			var selected_scene: PackedScene = _select(spawn_items)
			if not selected_scene:
				return
			var scene_instantiated: Node2D = selected_scene.instantiate()
			scene_instantiated.tree_entered.connect(func() -> void: scene_instantiated.global_position = body.global_position)
			magic.add_sibling(scene_instantiated)
			body.queue_free()
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