@abstract
class_name UiAnimationAbstract extends Node

signal ui_animation_finished

@export var path_to_ui: NodePath = ".."
@export var start_at_begin: bool

var start: bool = false
var ui: Control


func _ready() -> void:
	ui = get_node(path_to_ui)
	if not TitleAnimationManager.is_played:
		_ui_init()
	if start_at_begin and not TitleAnimationManager.is_played:
		_on_ui_animation_start()


@abstract
func _ui_init() -> void


func _process(delta: float) -> void:
	if not start: return
	_animation_process(delta)


@abstract
func _animation_process(delta: float) -> void


func _on_ui_animation_start() -> void:
	start = true


func _on_ui_animation_finished() -> void:
	emit_signal("ui_animation_finished")