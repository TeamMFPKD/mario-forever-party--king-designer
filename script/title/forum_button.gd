extends TextureButton

@export var forum_international_texture: Texture2D
@export var forum_cn_texture: Texture2D

var language

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	
func _process(_delta) -> void:
	language = TranslationServer.get_locale()
	if language == "zh":
		texture_normal = forum_cn_texture
	else:
		texture_normal = forum_international_texture
	
	
func _on_button_pressed():
	match language:
		"en":
			# Mario Forever Space
			OS.shell_open("https://marioforever.space/")
		"zh":
			# Mario Forever 社区
			OS.shell_open("https://www.marioforever.net/")
	
