extends Node

## 窗口化截图：垃圾桶房间。用临时 adventure.ini，不动真实数据。
##   Godot --path . res://tools/adventure_trash_shot.tscn

const OUTPUT: String = "res://tools/adventure_trash.png"
const TEMP_INI: String = "user://adventure_trash_shot.ini"
const ENTRY_COUNT: int = 9
const ROOM_SCENE: String = "res://room/adventure_trash.tscn"

var _temp_keys: Array[String] = []


func _ready() -> void:
	var backup_store: AdventureStore = Adventure.store
	var temp_store: AdventureStore = AdventureStore.new(TEMP_INI)
	temp_store.load()
	Adventure.store = temp_store

	for index: int in range(ENTRY_COUNT):
		var key: String = "adventure_trash_shot_%02d.lvl" % (index + 1)
		_temp_keys.append(key)
		var level_file: FileAccess = FileAccess.open("user://" + key, FileAccess.WRITE)
		if level_file != null:
			level_file.store_string("{\"probe\": true}")
			level_file.close()
		temp_store.set_excluded(key, true, "unsolvable")

	var packed: PackedScene = load(ROOM_SCENE) as PackedScene
	var room: Node = packed.instantiate()
	add_child(room)
	await get_tree().create_timer(0.8).timeout

	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(OUTPUT)

	Adventure.store = backup_store
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		for file_name: String in ["adventure_trash_shot.ini", "adventure_trash_shot.ini.tmp"]:
			if FileAccess.file_exists("user://" + file_name):
				dir.remove(file_name)
		for key: String in _temp_keys:
			if FileAccess.file_exists("user://" + key):
				dir.remove(key)
	get_tree().quit()
