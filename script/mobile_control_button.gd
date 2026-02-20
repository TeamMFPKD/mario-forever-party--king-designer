extends Button

@export var show_mode := MobileControl.ShowModeType.SHOW

var mobile_control : MobileControl

func _ready():
	# 运行平台检测
	if not (OS.has_feature("mobile")):
		hide()
		return

	mobile_control = get_tree().get_first_node_in_group("mobile_control")
	mobile_control.show_mode = show_mode
	update_button_text()
	pressed.connect(_on_pressed)

func _on_pressed():
	if mobile_control == null:
		return
	
	if mobile_control.show_mode == MobileControl.ShowModeType.SHOW:
		mobile_control.show_mode = MobileControl.ShowModeType.HIDE
	else:
		mobile_control.show_mode = MobileControl.ShowModeType.SHOW
	
	update_button_text()

func update_button_text():
	if mobile_control == null:
		return
	
	if mobile_control.show_mode == MobileControl.ShowModeType.SHOW:
		text = "隐藏触控"
	else:
		text = "显示触控"
