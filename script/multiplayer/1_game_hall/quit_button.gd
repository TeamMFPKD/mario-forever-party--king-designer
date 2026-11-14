extends UiSoundButton


func _ready() -> void:
	super()
	pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	MPManager.leave_room("主动退出")
