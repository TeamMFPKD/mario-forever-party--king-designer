extends Node

signal new_message_hint

signal play_sound_msg_open
signal play_sound_msg_close

@export var sidebar_show_button: Button
@export var control: Control

@export var debug: bool = false

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
	multiplayer_manager.messages_updated.connect(_on_messages_updated)
	sidebar_show_button.pressed.connect(_on_sidebar_show_button_pressed)
	_status_changed()

func _on_players_updated() -> void:
	enabled = multiplayer_manager.players.size() >= (2 if not debug else 1)

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
	emit_signal("play_sound_msg_open" if show else "play_sound_msg_close")

func _on_messages_updated() -> void:
	if status == Status.EXPANDED:
		return
	emit_signal("new_message_hint")