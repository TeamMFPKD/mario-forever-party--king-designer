extends Node

@export var sidebar_show_button: Button
@export var control: Control

var enabled: bool = false:
	set(value):
		enabled = value
		_status_changed()
var show: bool = true:
	set(value):
		show = value
		_status_changed()

var multiplayer_manager: MultiplayerManager

enum Status {
	DISABLED,
	COLLAPSED,
	EXPANDED,
}
var status: Status = Status.DISABLED

var _tween: Tween

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	multiplayer_manager.players_updated.connect(_on_players_updated)
	sidebar_show_button.pressed.connect(_on_sidebar_show_button_pressed)
	_status_changed()

func _on_players_updated() -> void:
	enabled = multiplayer_manager.players.size() >= 2

func _status_changed() -> void:
	if not enabled:
		status = Status.DISABLED
		multiplayer_manager.messages.clear()
	elif not show:
		status = Status.COLLAPSED
	else:
		status = Status.EXPANDED

	var target_x := _get_x_for_status(status)

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(control, "position:x", target_x, 0.3)

func _get_x_for_status(s: Status) -> float:
	match s:
		Status.DISABLED:
			return 0.0
		Status.COLLAPSED:
			return 64.0
		Status.EXPANDED:
			return 504.0
	return 0.0

func _on_sidebar_show_button_pressed() -> void:
	show = not show