extends Node

class_name EnemyDie

signal enemy_died

enum DeathType {
	DEFAULT,
	STOMP,
	FIREBALL,
	BEETROOT,
	STAR,
	SHELL,
	BUMP,
	CRUSH
}

var death_type: DeathType = DeathType.DEFAULT

var dead_instance : Node2D
var parent : Node2D

@export var path_to_animated_sprite : NodePath = "../AnimatedSprite2D"
var ani : AnimatedSprite2D
var dead_texture : Texture2D

@export var dead_scene_default : PackedScene = preload("uid://cllkdvixqmhrc")
@export var dead_texture_override : Texture2D

@export var dead_scene_stomp : PackedScene
@export var dead_scene_fireball : PackedScene
@export var dead_scene_beetroot : PackedScene
@export var dead_scene_star : PackedScene
@export var dead_scene_shell : PackedScene
@export var dead_scene_bump : PackedScene
@export var dead_scene_crush : PackedScene

# 交互组件连接控制
@export var enable_interaction_with_player: bool = true
@export var enable_interaction_with_fireball: bool = true
@export var enable_interaction_with_beetroot: bool = true
@export var enable_interaction_with_star: bool = true
@export var enable_interaction_with_shell: bool = true
@export var enable_interaction_with_bump: bool = true
@export var enable_interaction_with_crush: bool = true

# 交互组件配置映射表
const INTERACTION_CONFIG := {
	"interaction_with_player": {"signal": "stomped", "death_type": DeathType.STOMP},
	"interaction_with_fireball": {"signal": "fireball_hitted", "death_type": DeathType.FIREBALL},
	"interaction_with_beetroot": {"signal": "beetroot_hitted", "death_type": DeathType.BEETROOT},
	"interaction_with_star": {"signal": "star_hitted", "death_type": DeathType.STAR},
	"interaction_with_shell": {"signal": "shell_hitted", "death_type": DeathType.SHELL},
	"interaction_with_bump": {"signal": "bumped", "death_type": DeathType.BUMP},
	"interaction_with_crush": {"signal": "crushed_at", "death_type": DeathType.CRUSH}
}

# 防止多次触发
var is_dead: bool = false

func _ready() -> void:
	parent = get_parent() as Node2D
	ani = get_node(path_to_animated_sprite) as AnimatedSprite2D
	# 储存第一帧精灵内容
	dead_texture = ani.sprite_frames.get_frame_texture(ani.animation, ani.frame)
	
	# 自动连接所有交互组件信号
	for meta_name in INTERACTION_CONFIG:
		var config = INTERACTION_CONFIG[meta_name]
		if get_parent().has_meta(meta_name):
			var interaction = get_parent().get_meta(meta_name)
			var signal_name: String = config["signal"]
			var death_type: DeathType = config["death_type"]
			
			# 检查是否启用该交互
			var enable_property = "enable_" + meta_name
			if has_method("get") and get(enable_property):
				if interaction.has_signal(signal_name):
					interaction.connect(signal_name, _on_interaction_hit.bind(death_type))

func die(hit_position: Vector2 = Vector2.ZERO, death_type: DeathType = DeathType.DEFAULT) -> void:
	if is_dead:
		return
	is_dead = true
	dead_instantiate(hit_position,death_type)
	dead_instance.position = parent.position
	parent.add_sibling(dead_instance)
	parent.queue_free()
	emit_signal("enemy_died")

func dead_instantiate(hit_position: Vector2, death_type: DeathType = DeathType.DEFAULT) -> void:
	var scene_map = {
		DeathType.DEFAULT: dead_scene_default,
		DeathType.STOMP: dead_scene_stomp,
		DeathType.FIREBALL: dead_scene_fireball,
		DeathType.BEETROOT: dead_scene_beetroot,
		DeathType.BUMP: dead_scene_bump,
		DeathType.STAR: dead_scene_star,
		DeathType.SHELL: dead_scene_shell,
		DeathType.CRUSH: dead_scene_crush
	}
	
	var scene = scene_map[death_type]
	if not scene:
		scene = dead_scene_default
	
	dead_instance = scene.instantiate() as Node2D
	if scene == dead_scene_default:
		dead_instance.set_meta("enemy_dead_direction", 1 if hit_position.x < parent.position.x else -1)
		var dead_sprite_2d = dead_instance.get_node("Sprite2D") as Sprite2D
		dead_sprite_2d.texture = dead_texture
		if dead_texture_override:
			dead_sprite_2d.texture = dead_texture_override

# 统一的交互命中处理函数
func _on_interaction_hit(hit_position: Vector2, death_type: DeathType) -> void:
	die(hit_position,death_type)