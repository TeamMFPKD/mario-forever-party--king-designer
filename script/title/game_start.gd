extends Node

signal game_started

var multiplayer_manager : MultiplayerManager

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager

func _on_start_button_pressed() -> void:
	if not multiplayer_manager.multiplayer.is_server():
		return
	game_start.rpc()
	
func on_game_start() -> void:
	TimerSingleton.start()
	emit_signal("game_started")

@rpc("authority", "call_local")
func game_start() -> void:
	print("要开始了哟~")
	var current_time = Time.get_datetime_string_from_system(false, true)
	current_time = current_time.replace(":", "-")
	current_time = current_time.replace(" ", "_")
	MPManager.game_start_time = current_time
	on_game_start()
