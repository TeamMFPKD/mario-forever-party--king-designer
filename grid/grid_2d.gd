extends Node2D
class_name Grid2D

@export var grid_size := Vector2(32, 32)
@export var cell_size := 32
@export var line_color := Color(1, 1, 1, 0.3)
@export var line_width := 1.0
@export var draw_interval := 0.1  # 每条线开始绘制的间隔（秒）
@export var line_draw_speed := 100.0  # 线条绘制速度（像素/秒）

var current_line := 0
var total_lines := 0
var line_progress := {}  # 存储每条线的绘制进度
var timer: Timer
var animation_active := false

func _ready() -> void:
	# 计算总线条数
	var vertical_lines = int(grid_size.x + 1)
	var horizontal_lines = int(grid_size.y + 1)
	total_lines = vertical_lines + horizontal_lines
	
	# 创建定时器
	timer = Timer.new()
	timer.wait_time = draw_interval
	timer.timeout.connect(_draw_next_line)
	add_child(timer)
	
	# 添加一个处理线条进度的计时器
	var process_timer = Timer.new()
	process_timer.wait_time = 1.0 / 60.0  # 每秒60帧更新
	process_timer.timeout.connect(_process_line_progress)
	add_child(process_timer)
	process_timer.start()
	
	# 开始动画
	start_animation()

func _process_line_progress() -> void:
	if !animation_active:
		return
		
	var updated = false
	var all_completed = true
	
	for key in line_progress:
		if line_progress[key] < 1.0:
			line_progress[key] += line_draw_speed * (1.0 / 60.0) / get_line_length(key)
			if line_progress[key] > 1.0:
				line_progress[key] = 1.0
			else:
				all_completed = false  # 至少有一条线还没完成
			updated = true
	
	# 检查是否所有线都完成了绘制
	var all_lines_added = current_line >= total_lines
	if all_lines_added and all_completed:
		animation_active = false
		timer.stop()
		print("网格绘制完成！")
	
	if updated:
		queue_redraw()

func _draw() -> void:
	var total_size = grid_size * cell_size
	var vertical_lines = int(grid_size.x + 1)
	
	# 绘制垂直线
	for x in range(vertical_lines):
		var line_key = "v_%d" % x
		if line_progress.has(line_key):
			var x_pos = x * cell_size
			var max_length = total_size.y
			var current_length = max_length * line_progress[line_key]
			
			draw_line(
				Vector2(x_pos, 0),
				Vector2(x_pos, current_length),
				line_color,
				line_width
			)
	
	# 绘制水平线
	for y in range(int(grid_size.y + 1)):
		var line_key = "h_%d" % y
		# 移除 line_index < current_line 的条件，只要进度存在就绘制
		if line_progress.has(line_key):
			var y_pos = y * cell_size
			var max_length = total_size.x
			var current_length = max_length * line_progress[line_key]
			
			draw_line(
				Vector2(0, y_pos),
				Vector2(current_length, y_pos),
				line_color,
				line_width
			)

func _draw_next_line() -> void:
	if current_line < total_lines:
		var vertical_lines = int(grid_size.x + 1)
		
		# 同时为垂直线和水平线创建绘制任务
		# 当前是奇数次时添加垂直线，偶数次时添加水平线
		var line_index = current_line
		if line_index % 2 == 0 and line_index / 2 < vertical_lines:
			# 添加垂直线
			var v_line_idx = line_index / 2
			var line_key = "v_%d" % int(v_line_idx)
			line_progress[line_key] = 0.0
		elif (line_index % 2 == 1) and ((line_index - 1) / 2 < int(grid_size.y + 1)):
			# 添加水平线
			var h_line_idx = (line_index - 1) / 2
			var line_key = "h_%d" % int(h_line_idx)
			line_progress[line_key] = 0.0
		
		current_line += 1
		queue_redraw()
	else:
		# 所有线都已经开始绘制，但动画仍需继续直到所有线都完成
		# 不在这里停止timer，而是由_process_line_progress函数决定何时停止
		pass

func get_line_length(key: String) -> float:
	if key.begins_with("v_"):
		# 垂直线
		return grid_size.y * cell_size
	else:
		# 水平线
		return grid_size.x * cell_size

func start_animation() -> void:
	current_line = 0
	line_progress.clear()
	animation_active = true
	timer.start()
	queue_redraw()

func reset_animation() -> void:
	current_line = 0
	line_progress.clear()
	animation_active = false
	timer.stop()
	queue_redraw()