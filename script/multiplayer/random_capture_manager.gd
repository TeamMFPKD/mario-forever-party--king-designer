extends Node

var captures = []

func set_captures(player_id, capture) -> void:
	var player_capture = {
		"player_id": player_id,
		"capture": capture
	}
	captures.append(player_capture)

func get_capture(player_id: int) -> Texture2D:
	var player_captures = []
	for capture in captures:
		if capture["player_id"] == player_id:
			player_captures.append(capture["capture"])
	player_captures.shuffle()
	return player_captures[0]

func clear_captures() -> void:
	captures = []
	
