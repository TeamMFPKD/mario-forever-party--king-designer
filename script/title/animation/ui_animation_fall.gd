extends UiAnimationAbstract


var origin_pos: Vector2
var speed_y: float = 0.0
var is_bouncing: bool = false

const DAMPING = 0.70         # 衰减系数 (0~1)，越小衰减越快
const BOUNCE_STRENGTH = 8.0  # 反弹初始速度


func _ui_init() -> void:
	origin_pos = ui.position

func _animation_process(delta: float) -> void:
	# 应用速度
	ui.position.y += speed_y * delta * 60.0  # 乘以60使速度与帧率无关

	# 如果超过原点位置（向下超出）
	if ui.position.y > origin_pos.y:
		ui.position.y = origin_pos.y           # 复位到原点
		speed_y = -speed_y * DAMPING          # 反向并衰减

		# 如果速度太小，停止运动
		if abs(speed_y) < 0.5:
			speed_y = 0.0
			start = false                     # 动画结束
			_on_ui_animation_finished()
			return
		
	speed_y += 0.02 * 60.0

func _on_ui_animation_start() -> void:
	super._on_ui_animation_start()
	speed_y = BOUNCE_STRENGTH                 # 初始速度（向下）
	ui.position = origin_pos + Vector2.UP * 320.0
	ui.reset_physics_interpolation()
