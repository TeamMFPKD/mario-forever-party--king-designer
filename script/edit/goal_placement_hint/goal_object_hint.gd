extends Node

@export_category("Controls")
@export var mark_button: Control
@export var mark_panel: Control
@export_category("Hints")
@export var hint_to_mark: Control
@export var hint_to_goal: Control

enum HintState {
	NONE,
	HINT_MARK,
	HINT_GOAL,
}

var hint_state: HintState = HintState.NONE
var is_there_a_goal: bool = true

const GOAL_OBJECT_NAME: String = "goal_gate"


func _process(_delta: float) -> void:
	_update_hint_state()
	_show_hint()


func _update_hint_state() -> void:
	var level_control = get_tree().get_first_node_in_group("level_control") as LevelControl
	if is_there_a_goal or (level_control and level_control.current_object_name == GOAL_OBJECT_NAME):
		hint_state = HintState.NONE
	else:
		if not mark_panel.visible:
			hint_state = HintState.HINT_MARK
		else:
			hint_state = HintState.HINT_GOAL


func _show_hint() -> void:
	match hint_state:
		HintState.NONE:
			hint_to_mark.visible = false
			hint_to_goal.visible = false
		HintState.HINT_MARK:
			hint_to_mark.visible = true
			hint_to_goal.visible = false
		HintState.HINT_GOAL:
			hint_to_mark.visible = false
			hint_to_goal.visible = true


func _on_none_goal() -> void:
	is_there_a_goal = false

func _on_goal_exists() -> void:
	is_there_a_goal = true
