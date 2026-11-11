extends Button

## 语言切换按钮。语言状态的读写统一走 GameConfig，
## 这样初次运行的系统语言推断、设置保存、旧存档兼容都只有一处实现。

var current_language: String
## 可循环切换的语言顺序（日本語 l10n 已实装，但入口先保留注释状态）
var cycle: PackedStringArray = ["en", "zh_CN"]


func _ready() -> void:
	pressed.connect(_on_pressed)
	current_language = GameConfig.get_language()
	TranslationServer.set_locale(current_language)
	update_button_text()


func _on_pressed() -> void:
	var index: int = cycle.find(current_language)
	current_language = cycle[(index + 1) % cycle.size()]
	GameConfig.set_language(current_language)
	update_button_text()


func update_button_text() -> void:
	match current_language:
		"en":
			text = "English"
		"zh_CN":
			text = "中文"
		"ja":
			text = "日本語"
