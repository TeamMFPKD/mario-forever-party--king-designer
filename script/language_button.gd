extends Button

enum LanguageType {
	EN,
	ZH,
	ja,
}

var config : ConfigFile
var current_language : String

func _ready():
	# 连接按钮点击信号
	pressed.connect(_on_pressed)

	config = GameConfig.config

	current_language = config.get_value("options", "language", "en")
	match current_language:
		"en":
			TranslationServer.set_locale("en")
		"zh":
			TranslationServer.set_locale("zh")
		"ja":
			TranslationServer.set_locale("ja")

	# 更新按钮文字
	update_button_text()

func _on_pressed():	
	# 切换语言
	if current_language == "en":
		current_language = "zh"
	elif current_language == "zh":
		current_language = "ja"
	elif current_language == "ja":
		current_language = "en"
		
	TranslationServer.set_locale(current_language)
	config.set_value("options", "language", current_language)
	
	# 更新按钮文字
	update_button_text()

	GameConfig.save()

func update_button_text():
	#var current_language = TranslationServer.get_locale()
	match current_language:
		"en":
			text = "English"
		"zh":
			text = "中文"
		"ja":
			text = "日本語"
