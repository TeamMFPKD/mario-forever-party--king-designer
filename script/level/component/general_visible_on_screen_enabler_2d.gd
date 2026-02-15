extends VisibleOnScreenEnabler2D

class_name GeneralVisibleOnScreenEnabler2d

@export var disable_when_out_of_screen: bool = false
@export var free_when_disabled_out_of_screen: bool = true

var _parent: Node

func _ready():
	_parent = get_node(enable_node_path)

func _on_screen_entered():
	if _parent == null:
		print("GeneralVisibleOnScreenEnabler2d: _parent is null!")
		return
	
	_parent.process_mode = Node.PROCESS_MODE_INHERIT
	if not disable_when_out_of_screen and free_when_disabled_out_of_screen:
		queue_free()