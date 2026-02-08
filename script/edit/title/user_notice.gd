extends MarginContainer

@export var refuse_button : Button
@export var accept_button : Button

var config : ConfigFile

func _ready():
	config = GameConfig.config
	var accept = config.get_value("user_notice", "accept", false)
	if accept:
		visible = false
		return
	refuse_button.pressed.connect(_on_refuse_button_pressed)
	accept_button.pressed.connect(_on_accept_button_pressed)

func _on_refuse_button_pressed():
	get_tree().quit()
	print("拒绝并退出")

func _on_accept_button_pressed():
	visible = false
	config.set_value("user_notice", "accept", true)
	GameConfig.save()