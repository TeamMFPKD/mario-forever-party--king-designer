extends Node

## 无敌星视觉：与 MFCE 一致的 HSV 彩虹、亮度闪烁与星星粒子。
## 由 PlayerSuit 的 starman_started / starman_ended 信号驱动，不改变任何玩法逻辑。

const SLOWED_DOWN_TIME: float = 1.5

@export var sprite: AnimatedSprite2D
@export var stars: CPUParticles2D
@export var player_suit: PlayerSuit

var _material: ShaderMaterial
var _slowed_down: bool = false

func _ready() -> void:
	if sprite == null:
		return
	# 联机时同名场景会有多个实例，材质必须各自独立，否则一人吃星全员变色
	var source_material: ShaderMaterial = sprite.material as ShaderMaterial
	if source_material != null:
		_material = source_material.duplicate() as ShaderMaterial
		sprite.material = _material

func _physics_process(_delta: float) -> void:
	if _material == null or player_suit == null or _slowed_down:
		return
	if not player_suit.is_starman:
		return
	var remain_frames: int = player_suit.starman_time - player_suit.starman_timer
	var remain_seconds: float = float(remain_frames) / float(Engine.physics_ticks_per_second)
	if remain_seconds <= SLOWED_DOWN_TIME:
		_slowed_down = true
		_material.set_shader_parameter(&"slowed_down", true)

func _on_starman_start() -> void:
	_slowed_down = false
	if _material != null:
		_material.set_shader_parameter(&"mixing", true)
		_material.set_shader_parameter(&"slowed_down", false)
	if stars != null:
		stars.emitting = true

func _on_starman_end() -> void:
	_slowed_down = false
	if _material != null:
		_material.set_shader_parameter(&"mixing", false)
		_material.set_shader_parameter(&"slowed_down", false)
	if stars != null:
		stars.emitting = false
