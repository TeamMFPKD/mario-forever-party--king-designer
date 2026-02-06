extends BasicMovement

signal jump_speed_set

@export var path_to_visible_detect : NodePath = "../GeneralVisibleOnScreenEnabler2d"

var is_in_screen : bool = true
var visible_detect : VisibleOnScreenNotifier2D

func _ready() -> void:
	super._ready()
	visible_detect = get_node(path_to_visible_detect)

func set_jump_speed():
	if move_object.is_on_floor() and is_in_screen:
		emit_signal("jump_speed_set")
	super.set_jump_speed()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	is_in_screen = visible_detect.is_on_screen()
