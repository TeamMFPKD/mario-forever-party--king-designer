extends Button

var user_path: String = "user://"
var absolute_path: String

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	absolute_path = ProjectSettings.globalize_path(user_path)
	
func _on_button_pressed() -> void:
	OS.shell_open(absolute_path)
