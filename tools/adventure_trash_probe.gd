extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 无头探针：验证「垃圾桶」房间（永久排除列表 + 逐关恢复 + 空态）。
## 全程使用临时 adventure.ini 与临时 .lvl，不读写真实的 user://adventure.ini。
##   Godot --headless --path . res://tools/adventure_trash_probe.tscn

const OUTPUT: String = "res://tools/adventure_trash_probe_result.txt"
const TEMP_INI: String = "user://adventure_trash_probe.ini"
const TEMP_KEY: String = "adventure_trash_probe_level.lvl"
const MISSING_KEY: String = "adventure_trash_probe_missing.lvl"
const ROOM_SCENE: String = "res://room/adventure_trash.tscn"
const STAGE_SCENE: String = "res://room/adventure_stage.tscn"

const LIST_PATH: String = "GameRoomSize/UiMarginContainer/UiMarginContainer/VBoxContainer/ScrollContainer/TrashList"
const TITLE_PATH: String = "GameRoomSize/UiMarginContainer/UiMarginContainer/VBoxContainer/UiLabel"
const EMPTY_PATH: String = "GameRoomSize/UiMarginContainer/UiMarginContainer/EmptyLabel"
const SCROLL_PATH: String = "GameRoomSize/UiMarginContainer/UiMarginContainer/VBoxContainer/ScrollContainer"


func _ready() -> void:
	var lines: Array[String] = []
	var backup_store: AdventureStore = Adventure.store
	var temp_store: AdventureStore = AdventureStore.new(TEMP_INI)
	temp_store.load()
	Adventure.store = temp_store

	var level_file: FileAccess = FileAccess.open("user://" + TEMP_KEY, FileAccess.WRITE)
	if level_file != null:
		level_file.store_string("{\"probe\": true}")
		level_file.close()
	temp_store.set_excluded(TEMP_KEY, true, "unsolvable")
	temp_store.set_excluded(MISSING_KEY, true, "manual")

	var room_packed: PackedScene = load(ROOM_SCENE) as PackedScene
	var room: Node = room_packed.instantiate()
	add_child(room)
	await get_tree().process_frame

	var level_list: VBoxContainer = room.get_node(LIST_PATH) as VBoxContainer
	var title_label: Label = room.get_node(TITLE_PATH) as Label
	var empty_label: Label = room.get_node(EMPTY_PATH) as Label
	var scroll: ScrollContainer = room.get_node(SCROLL_PATH) as ScrollContainer

	lines.append("row_count=%d" % level_list.get_child_count())
	lines.append("title_text=%s" % title_label.text)
	lines.append("empty_hidden=%s" % str(not empty_label.visible))
	lines.append("scroll_visible=%s" % str(scroll.visible))

	var row_texts: PackedStringArray = PackedStringArray()
	for child: Node in level_list.get_children():
		var row: AdventureTrashRow = child as AdventureTrashRow
		if row != null:
			row_texts.append("%s|view_disabled=%s" % [row.name_label.text, str(row.view_button.disabled)])
	lines.append("rows=%s" % " ;; ".join(row_texts))

	var existing_row: AdventureTrashRow = null
	for child: Node in level_list.get_children():
		var row: AdventureTrashRow = child as AdventureTrashRow
		if row != null and row.key == TEMP_KEY:
			existing_row = row
			break
	if existing_row != null:
		lines.append("edit_bind=%s" % str(bool(room.call("_bind_history_edit_context", existing_row.level_path))))
		var path_set: Node = get_tree().get_first_node_in_group("level_path_set")
		lines.append("edit_path=%s" % str(path_set.get_meta("level_path_name", "")))
		lines.append("edit_return=%s" % str(path_set.get_meta("return_scene_path", "")))
		lines.append("edit_mode=%s" % str(GameMode.is_history_edit()))
		GameModeSingleton.game_mode = GameMode.GameModeType.ADVENTURE

	var first_key: String = ""
	for child: Node in level_list.get_children():
		var row: AdventureTrashRow = child as AdventureTrashRow
		if row != null and row.key == TEMP_KEY:
			first_key = row.key
			row.restore_button.pressed.emit()
			break
	lines.append("restore_pressed=%s" % first_key)
	await get_tree().process_frame
	lines.append("excluded_after=%s" % str(temp_store.is_excluded(TEMP_KEY)))
	lines.append("row_count_after=%d" % level_list.get_child_count())
	lines.append("title_after=%s" % title_label.text)

	for child: Node in level_list.get_children():
		var row: AdventureTrashRow = child as AdventureTrashRow
		if row != null and row.key == MISSING_KEY:
			row.restore_button.pressed.emit()
			break
	await get_tree().process_frame
	lines.append("empty_visible=%s" % str(empty_label.visible))
	lines.append("scroll_hidden=%s" % str(not scroll.visible))
	lines.append("title_final=%s" % title_label.text)

	var stage_packed: PackedScene = load(STAGE_SCENE) as PackedScene
	var stage: Node = stage_packed.instantiate()
	lines.append("stage_overlay_removed=%s" % str(stage.get_node_or_null("AdventureTrashPanel") == null))
	var stage_script: Script = stage.get_script() as Script
	var constants: Dictionary = stage_script.get_script_constant_map()
	lines.append("stage_trash_scene=%s" % str(constants.get("TRASH_SCENE", "")))
	stage.free()

	Adventure.store = backup_store
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		for file_name: String in ["adventure_trash_probe.ini", "adventure_trash_probe.ini.tmp", TEMP_KEY]:
			if FileAccess.file_exists("user://" + file_name):
				dir.remove(file_name)

	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	get_tree().quit()
