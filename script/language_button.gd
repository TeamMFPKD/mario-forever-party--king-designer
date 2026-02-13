extends Button

var config : ConfigFile

func _ready():
	# 设置按钮初始文本
	update_button_text()
	# 连接按钮点击信号
	pressed.connect(_on_pressed)

	config = GameConfig.config

	var language = config.get_value("options", "language", "en")
	match language:
		"en":
			TranslationServer.set_locale("en")
		"zh":
			TranslationServer.set_locale("zh")

	# 更新按钮文字
	update_button_text()


func _on_pressed():
	# 获取当前语言
	var current = TranslationServer.get_locale()
	
	# 切换语言
	if current == "zh":
		TranslationServer.set_locale("en")
		config.set_value("options", "language", "en")
	else:
		TranslationServer.set_locale("zh")
		config.set_value("options", "language", "zh")
	
	# 更新按钮文字
	update_button_text()

	GameConfig.save()

func update_button_text():
	# 按钮上显示当前语言的另一选项
	if TranslationServer.get_locale() == "zh":
		text = "English"  # 当前是中文，按钮显示English
	else:
		text = "中文"      # 当前是英文，按钮显示中文