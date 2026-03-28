extends ControlVisibieSet

var mobile_control
var game_config
var is_dragging = false
var drag_start_pos = Vector2.ZERO
var drag_target = null

func _ready():
	super._ready()
	mobile_control = get_tree().get_first_node_in_group("mobile_control")
	game_config = GameConfig
	_load_positions()
	# Connect input handling to the control node
	if control:
		control.gui_input.connect(_on_canvas_gui_input)

func _set_visible():
	super._set_visible()
	mobile_control.show_mode = MobileControl.ShowModeType.SHOW

func _set_invisible():
	super._set_invisible()
	mobile_control.show_mode = MobileControl.ShowModeType.HIDE

func _on_canvas_gui_input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			# Check which area is being touched
			var touch_pos = event.position
			drag_target = _get_target_from_position(touch_pos)
			if drag_target:
				is_dragging = true
				drag_start_pos = touch_pos - drag_target.position
		else:
			if is_dragging:
				is_dragging = false
				drag_target = null
				_save_positions()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if is_dragging and drag_target:
			drag_target.position = event.position - drag_start_pos

func _get_target_from_position(pos):
	# Check if touch is within D-pad area
	if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
		var dpad_container = mobile_control.control_d_pad.get_node("ControlDPad")
		var dpad_global_pos = mobile_control.control_d_pad.global_position + dpad_container.position
		# Simple bounding box check (adjust size as needed)
		var dpad_rect = Rect2(dpad_global_pos - Vector2(300, 300), Vector2(600, 600))
		if dpad_rect.has_point(pos):
			return dpad_container
	
	# Check if touch is within buttons area
	if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
		var button_container = mobile_control.control_button.get_node("ControlButton")
		var button_global_pos = mobile_control.control_button.global_position + button_container.position
		# Simple bounding box check (adjust size as needed)
		var button_rect = Rect2(button_global_pos - Vector2(300, 300), Vector2(600, 600))
		if button_rect.has_point(pos):
			return button_container
	
	return null

func _save_positions():
	if game_config:
		# Save D-pad position
		if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
			var dpad_container = mobile_control.control_d_pad.get_node("ControlDPad")
			game_config.config.set_value("mobile_layout", "dpad_position", str(dpad_container.position))
		
		# Save buttons position
		if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
			var button_container = mobile_control.control_button.get_node("ControlButton")
			game_config.config.set_value("mobile_layout", "buttons_position", str(button_container.position))
		
		game_config.save()

func _load_positions():
	if game_config:
		# Load D-pad position
		if mobile_control.control_d_pad and mobile_control.control_d_pad.has_node("ControlDPad"):
			var dpad_container = mobile_control.control_d_pad.get_node("ControlDPad")
			var dpad_pos_str = game_config.config.get_value("mobile_layout", "dpad_position", "")
			if dpad_pos_str:
				var dpad_pos = str_to_var(dpad_pos_str)
				if dpad_pos is Vector2:
					dpad_container.position = dpad_pos
		
		# Load buttons position
		if mobile_control.control_button and mobile_control.control_button.has_node("ControlButton"):
			var button_container = mobile_control.control_button.get_node("ControlButton")
			var buttons_pos_str = game_config.config.get_value("mobile_layout", "buttons_position", "")
			if buttons_pos_str:
				var buttons_pos = str_to_var(buttons_pos_str)
				if buttons_pos is Vector2:
					button_container.position = buttons_pos