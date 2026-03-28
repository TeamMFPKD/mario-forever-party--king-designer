extends Sprite2D

@export var path_to_button : NodePath = ".."
@export var texture_pressed : Texture2D

var button : TouchScreenButton
var texture_normal : Texture2D

@export var pressed_color : Color = Color(1, 1, 1, 1)
var origin_color : Color

func _ready() -> void:
	#texture_normal = texture.duplicate()
	button = get_node(path_to_button) as TouchScreenButton
	origin_color = self_modulate
	button.pressed.connect(_on_button_pressed)
	button.released.connect(_on_button_released)

func _on_button_pressed() -> void:
	#texture = texture_pressed
	self_modulate = pressed_color
	
func _on_button_released() -> void:
	#texture = texture_normal
	self_modulate = origin_color
