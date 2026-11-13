extends Node

@warning_ignore_start("unsafe_call_argument", "unsafe_cast")

const TEMP_STORE: String = "user://adventure_abandon_probe.ini"


func _ready() -> void:
	var store: AdventureStore = AdventureStore.new(TEMP_STORE)
	store.load()
	Adventure.store = store
	if not Adventure.start_run({
		"pool_source": "all",
		"tier": 0,
		"mode": "finite",
		"run_length": 5,
		"prefer_low_sample": true,
	}):
		get_tree().quit()
		return
	Adventure.on_level_loaded(Adventure.current_level_path())
	Adventure.abandon_run()
	await get_tree().process_frame
	get_tree().change_scene_to_file(Adventure.result_scene())
	await get_tree().create_timer(0.8).timeout
	var current: Node = get_tree().current_scene
	print("[AbandonProbe] current_scene=", current.name if current != null else "null")
	print("[AbandonProbe] summary=", Adventure.last_summary)
	_cleanup()
	get_tree().quit()


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in ["adventure_abandon_probe.ini", "adventure_abandon_probe.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
