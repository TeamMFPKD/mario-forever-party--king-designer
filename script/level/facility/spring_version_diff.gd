extends Node

var screen_notifier: VisibleOnScreenEnabler2D


func _enter_tree() -> void:
	var level_manager = get_tree().get_first_node_in_group("level_manager") as LevelManager
	screen_notifier = get_parent() as VisibleOnScreenEnabler2D
	var target_node = screen_notifier.get_node_or_null(screen_notifier.enable_node_path)
	if not target_node:
		return
	if level_manager.version < 2:
		var target_enable_mode: ProcessMode
		match screen_notifier.enable_mode:
			VisibleOnScreenEnabler2D.EnableMode.ENABLE_MODE_INHERIT:
				target_enable_mode = ProcessMode.PROCESS_MODE_INHERIT
			VisibleOnScreenEnabler2D.EnableMode.ENABLE_MODE_ALWAYS:
				target_enable_mode = ProcessMode.PROCESS_MODE_ALWAYS
			VisibleOnScreenEnabler2D.EnableMode.ENABLE_MODE_WHEN_PAUSED:
				target_enable_mode = ProcessMode.PROCESS_MODE_WHEN_PAUSED
		target_node.process_mode = target_enable_mode

		screen_notifier.queue_free()
