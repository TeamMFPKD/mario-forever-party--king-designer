extends Button

signal mobile_platform_invisible

# 分辨率选项（16:9）
var resolutions = [
	{"name": "1920 × 1080", "width": 1920, "height": 1080},
	{"name": "1280 × 720", "width": 1280, "height": 720},
	{"name": "854 × 480", "width": 854, "height": 480}
]
var current_index = 0
var config

func _ready():
	# 移动端按钮不可视
	if not PlatformUtils.is_desktop_platform():
		_resolution_mobile_platform_invisible()
		return
	
	# 获取全局配置单例
	config = GameConfig
	
	# 读取保存的分辨率配置
	var saved_res = config.config.get_value("display", "resolution", "1920 × 1080")
	# 查找匹配的分辨率索引
	for i in range(resolutions.size()):
		if resolutions[i]["name"] == saved_res:
			current_index = i
			break
	
	# 设置初始按钮文本和应用分辨率
	update_button_text()
	var engine_time_mesc = Time.get_ticks_msec()
	if engine_time_mesc < 5000.0:
		print("[设置] 加载屏幕分辨率设置：" + saved_res)	
		apply_resolution()
	
	# 连接点击信号
	pressed.connect(_on_button_pressed)

func _on_button_pressed():
	# 切换到下一个分辨率
	current_index = (current_index + 1) % resolutions.size()
	
	# 应用分辨率并更新按钮文本
	apply_resolution()
	update_button_text()
	
	# 保存配置
	config.config.set_value("display", "resolution", resolutions[current_index]["name"])
	config.save()

func update_button_text():
	# 更新按钮文本为当前分辨率
	text = resolutions[current_index]["name"]

func apply_resolution():
	# 应用当前选中的分辨率
	var res = resolutions[current_index]
	var window = get_window()
	
	# 如果窗口处于最大化状态，只在游戏启动1秒内取消最大化
	if window.mode == Window.MODE_MAXIMIZED:
		window.mode = Window.MODE_WINDOWED
	
	# 设置窗口大小（Godot 4.x API）
	window.size = Vector2i(res["width"], res["height"])
	
	# 居中窗口
	var screen_size = DisplayServer.screen_get_size()
	var window_position = (screen_size - window.size) / 2
	window.position = Vector2i(window_position.x, window_position.y)

func _resolution_mobile_platform_invisible() -> void:
	emit_signal("mobile_platform_invisible")