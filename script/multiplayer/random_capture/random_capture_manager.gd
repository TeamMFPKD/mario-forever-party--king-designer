extends Node

var captures: Array = []

func set_captures(player_id: Variant, capture: Texture2D) -> void:
	var player_capture: Dictionary = {
		"player_id": player_id,
		"capture": capture
	}
	captures.append(player_capture)

func get_capture(player_id: int) -> Texture2D:
	var player_captures: Array = []
	for capture: Dictionary in captures:
		if capture["player_id"] == player_id:
			player_captures.append(capture["capture"])
	player_captures.shuffle()
	var result: Texture2D = player_captures[0]
	return result

func clear_captures() -> void:
	captures = []