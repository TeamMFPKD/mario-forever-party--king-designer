extends LineEdit

const PLAYER_ACTIONS := ["move_up", "move_down", "move_left", "move_right", "move_fire", "move_jump", "restart", "photo"]

var _saved_events: Dictionary = {}

func _ready():
	focus_entered.connect(_block)
	focus_exited.connect(_restore)
	tree_exiting.connect(_restore)

func _block():
	_saved_events.clear()
	for action in PLAYER_ACTIONS:
		var key_events: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				key_events.append(event)
				InputMap.action_erase_event(action, event)
		if not key_events.is_empty():
			_saved_events[action] = key_events

func _restore():
	for action in _saved_events:
		for event in _saved_events[action]:
			InputMap.action_add_event(action, event)
	_saved_events.clear()
