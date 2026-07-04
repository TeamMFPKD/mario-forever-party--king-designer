extends Button

var config: ConfigFile
var current_language: String


func _ready():
	pressed.connect(_on_pressed)

	config = GameConfig.config

	current_language = config.get_value("options", "language", "en")
	match current_language:
		"en":
			TranslationServer.set_locale("en")
		"zh_CN":
			TranslationServer.set_locale("zh_CN")
		"ja":
			TranslationServer.set_locale("ja")

		# Old version patch
		"zh":
			TranslationServer.set_locale("zh_CN")
			current_language = "zh_CN"

	# 更新按钮文字
	update_button_text()

func _on_pressed():	
	# 切换语言
	if current_language == "en":
		current_language = "zh_CN"
	elif current_language == "zh_CN":
		current_language = "en"
	# 日本語の l10n 实装完了，但修改ini设置文件只能。
	#	current_language = "ja"
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
		"zh_CN":
			text = "中文"
		"ja":
			text = "日本語"
