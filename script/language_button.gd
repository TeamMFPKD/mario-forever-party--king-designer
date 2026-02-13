extends Button

func _ready():
	# 设置按钮初始文本
	update_button_text()
	# 连接按钮点击信号
	pressed.connect(_on_pressed)

func _on_pressed():
	# 获取当前语言
	var current = TranslationServer.get_locale()
	
	# 切换语言
	if current == "zh":
		TranslationServer.set_locale("en")
	else:
		TranslationServer.set_locale("zh")
	
	# 更新按钮上的文字
	update_button_text()

func update_button_text():
	# 按钮上显示当前语言的另一选项
	if TranslationServer.get_locale() == "zh":
		text = "English"  # 当前是中文，按钮显示English
	else:
		text = "中文"      # 当前是英文，按钮显示中文