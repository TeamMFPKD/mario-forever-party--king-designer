extends Node2D

@export_enum("Random", "Marker") var move_mode: int
@export_range(0, 192, 16) var safe_range: float
@export var magic_scene: PackedScene

@onready var shape_cast_2d = $ShapeCast2D
@onready var shape_cast_2d2 = $ShapeCast2D2
@onready var magikoopa = get_parent()
@onready var sprite = get_parent().get_node("AnimatedSprite2D")
@onready var collision = $"../CollisionShape2D"

var player: Node2D
var player_position: Vector2
var place = []
var processing: bool = false


func _ready():
	sprite.modulate.a = 0
	player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(_delta: float) -> void:
	if not processing:
		processing = true
		attack()

	if player and sprite.modulate.a > 0:
		sprite.flip_h = magikoopa.global_position.x > player.global_position.x


func attack():
	var tween_1 = create_tween().tween_property(sprite, "modulate:a", 1, 0.34)
	await tween_1.finished
	collision.disabled = false

	await get_tree().create_timer(1.0, false, true).timeout

	var magic = magic_scene.instantiate()
	magic.connect("tree_entered", func(): magic.global_position = magikoopa.global_position)
	get_parent().add_sibling(magic)
	$MagicSE.play()

	await get_tree().create_timer(1.0, false, true).timeout

	collision.disabled = true
	var tween_2 = create_tween().tween_property(sprite, "modulate:a", 0, 0.34)
	await tween_2.finished

	await get_tree().create_timer(1.0, false, true).timeout

	var canvas = get_canvas_transform()
	var top_left = snapped(-canvas.origin / canvas.get_scale(), Vector2(32, 32))
	var size = snapped(get_viewport_rect().size / canvas.get_scale(), Vector2(32, 32))

	magikoopa.global_position = Vector2i(top_left.x + 16, top_left.y + 16)
	place.clear()

	if is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if player:
			player_position = player.global_position

	while magikoopa.global_position.x < (top_left.x + size.x) or place.is_empty():
		shape_cast_2d.force_shapecast_update()
		shape_cast_2d2.force_shapecast_update()

		if shape_cast_2d.is_colliding() \
		and not shape_cast_2d2.is_colliding():
			if is_instance_valid(player) \
			and magikoopa.global_position.distance_to(player_position) > safe_range:
				place.append(magikoopa.global_position)
			elif not is_instance_valid(player):
				place.append(magikoopa.global_position)

		magikoopa.global_position.y += 32

		if magikoopa.global_position.y > top_left.y + size.y:
			magikoopa.global_position.x += 32
			magikoopa.global_position.y = top_left.y + 16
		if magikoopa.global_position.x >= top_left.x + size.x and place.is_empty():
			break

	if not place.is_empty():
		magikoopa.global_position = place.pick_random()
	processing = false
