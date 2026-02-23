extends BasicMovement

# 允许的角度列表（以度为单位，竖直向下为0°，顺时针递增）
var ALLOWED_ANGLES = [45.0, 67.5, 112.5, 135.0, -45.0, -67.5, -112.5, -135.0]

# 火球速度
@export var fireball_speed: float = 150.0

func _ready() -> void:
	super._ready()
	
	# 计算火球到玩家的方向向量
	var direction_to_player = player.position - move_object.position
	
	# 计算角度（竖直向下为0°，顺时针递增）
	var angle_rad = atan2(direction_to_player.x, direction_to_player.y)
	var angle_deg = rad_to_deg(angle_rad)
	
	# 确保角度在0°-360°范围内
	if angle_deg < 0:
		angle_deg += 360.0
	
	# 选择最接近的允许角度
	var selected_angle = find_closest_angle(angle_deg)
	
	# 设置火球速度
	set_fireball_velocity(selected_angle)

# 找到最接近的允许角度
func find_closest_angle(target_angle: float) -> float:
	var closest_angle = ALLOWED_ANGLES[0]
	var min_difference = 360.0
	
	for angle in ALLOWED_ANGLES:
		# 将负角度转换为对应的正角度进行比较
		var normalized_angle = angle
		if normalized_angle < 0:
			normalized_angle += 360.0
		
		# 计算角度差（考虑360°循环）
		var difference = abs(normalized_angle - target_angle)
		difference = min(difference, 360.0 - difference)
		
		if difference < min_difference:
			min_difference = difference
			closest_angle = angle
	
	return closest_angle

# 根据角度设置火球速度
func set_fireball_velocity(angle_deg: float) -> void:
	# 将角度转换为弧度
	var angle_rad = deg_to_rad(angle_deg)
	
	# 计算速度分量（注意坐标系：x向右，y向下）
	var velocity_x = fireball_speed * sin(angle_rad)
	var velocity_y = fireball_speed * cos(angle_rad)
	print(velocity_x, velocity_y)
	
	# 设置速度
	speed_x = velocity_x
	speed_y = velocity_y
	
	# 禁用重力，实现匀速直线运动
	gravity = 0.0

func _physics_process(delta: float) -> void:
	speed_y_process(delta)
	apply_speed()
	move()