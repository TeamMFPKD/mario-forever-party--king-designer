extends Node

class_name InteractionWithCrush

signal crushed_at(crush_position: Vector2)

@export var path_to_basic_movement: NodePath = "../../BasicMovement"

@export var is_crushable : bool = true
@export var immune_to_crush : bool = false

var basic_movement: BasicMovement

func _ready() -> void:
	metadata_inject()

func metadata_inject() -> void:
	get_parent().set_meta("interaction_with_crush", self)
	basic_movement = _get_basic_movement()
	if not basic_movement:
		return
	basic_movement.crushed_at.connect(on_crush_hit)

func on_crush_hit(crush_position: Vector2) -> void:
	if not is_crushable:
		return
	if immune_to_crush:
		return
	emit_signal("crushed_at", crush_position)
	
func _get_basic_movement() -> BasicMovement:
	return get_node_or_null(path_to_basic_movement)