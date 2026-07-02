extends Node

@export var path_to_move_object: NodePath = "../"
@export var path_to_ani: NodePath = "../AnimatedSprite2D"
@export var effect_scene: PackedScene

var ani: AnimatedSprite2D
var texture: Texture2D
var parent: Node2D

func _ready() -> void:
	ani = get_node(path_to_ani) as AnimatedSprite2D
	texture = ani.sprite_frames.get_frame_texture(ani.animation, 0)
	parent = get_node(path_to_move_object) as Node2D

func _physics_process(_delta: float) -> void:
	pass  # Effect creation is now controlled via trigger_effect()

func trigger_effect() -> void:
	var effect = effect_scene.instantiate() as Node2D
	effect.position = parent.position
	parent.add_sibling(effect)
	
