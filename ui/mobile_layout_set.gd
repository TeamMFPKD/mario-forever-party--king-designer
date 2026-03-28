extends ControlVisibieSet

var mobile_control

func _ready():
	super._ready()
	mobile_control = get_tree().get_first_node_in_group("mobile_control")

func _set_visible():
	super._set_visible()
	mobile_control.show_mode = MobileControl.ShowModeType.SHOW

func _set_invisible():
	super._set_invisible()
	mobile_control.show_mode = MobileControl.ShowModeType.HIDE