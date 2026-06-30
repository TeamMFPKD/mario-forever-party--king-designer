extends Node

class_name InteractionWithPlayer

signal stomped(hit_position: Vector2)
signal overlapped

enum HurtType {
	HURT,
	DIE,
	NOTHING
}

@export var interactable: bool = true

@export_category("HurtType")
@export var hurt_type: HurtType = HurtType.HURT

@export_category("Stompable")
@export var stompable: bool = true
@export var stomp_offset: float = -4.0

@export var return_stomp_speed_y: bool = true
@export var stomp_speed_y: float = -550.0

@export var starman_stompable: bool = false

func _ready() -> void:
	metadata_inject()

func metadata_inject() -> void:
	get_parent().set_meta("interaction_with_player", self)
	
func on_stomped(stomper: CharacterBody2D) -> float:
	emit_signal("stomped", stomper.position)
	return stomp_speed_y
	
func on_overlap(_player: CharacterBody2D):
	emit_signal("overlapped")
	