extends Button

@export var is_desktop_button = true

func _ready() -> void:
	if PlatformUtils.is_desktop_platform() and not is_desktop_button:
		visible = false
	if PlatformUtils.is_mobile_platform() and is_desktop_button:
		visible = false