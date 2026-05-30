extends Label

func _ready() -> void:
	var version = ProjectSettings.get_setting("application/config/version")
	text = version
	print("[Game Version] ", version)
