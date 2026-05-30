extends MarginContainer

signal notice_accepted

@export var refuse_button : Button
@export var accept_button : Button

var config : ConfigFile

const USER_NOTICE_SECTION = "user_notice_v2"

func _ready():
	visible = true
	config = GameConfig.config
	var accept = config.get_value(USER_NOTICE_SECTION, "accept", false)
	if accept:
		emit_signal("notice_accepted")
		visible = false
		return
	refuse_button.pressed.connect(_on_refuse_button_pressed)
	accept_button.pressed.connect(_on_accept_button_pressed)

func _on_refuse_button_pressed():
	get_tree().quit()
	print("[user_notice.gd] 拒绝并退出")

func _on_accept_button_pressed():
	visible = false
	config.set_value(USER_NOTICE_SECTION, "accept", true)
	GameConfig.save()