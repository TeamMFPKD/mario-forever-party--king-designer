extends Node

class_name GameMode

signal mode_set_to_edit
signal mode_set_to_test
signal mode_set_to_play
signal mode_set_to_adventure

enum GameModeType {
	EDIT,
	TEST,
	PLAY,
	HISTORY_EDIT,
	HISTORY_PLAY,
	ADVENTURE,
}

@export var game_mode: GameModeType = GameModeType.EDIT:
	set(value):
		match value:
			GameModeType.EDIT:
				emit_signal("mode_set_to_edit")
			GameModeType.TEST:
				emit_signal("mode_set_to_test")
			GameModeType.PLAY:
				emit_signal("mode_set_to_play")
			GameModeType.ADVENTURE:
				emit_signal("mode_set_to_adventure")
		game_mode = value
@export var edit_scene_uid: String

func go_to_edit() -> void:
	await get_tree().create_timer(0.5, true, true).timeout
	game_mode = GameModeType.EDIT
	get_tree().paused = false
	GlobalTransition.change_scene_to_file(edit_scene_uid)


## 查询当前模式。autoload 指向 .tscn，静态类型会退化成 Node；
## 用静态方法统一读，避免各处被 unsafe_property_access（警告即错误）卡住。
static func _current_mode() -> Variant:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var node: Node = tree.root.get_node_or_null("GameModeSingleton")
	if node == null:
		return null
	return node.get("game_mode")


static func is_adventure() -> bool:
	return _current_mode() == GameModeType.ADVENTURE


static func is_history_play() -> bool:
	return _current_mode() == GameModeType.HISTORY_PLAY


static func is_history_edit() -> bool:
	return _current_mode() == GameModeType.HISTORY_EDIT


static func is_playing() -> bool:
	return _current_mode() == GameModeType.PLAY


static func is_testing() -> bool:
	return _current_mode() == GameModeType.TEST


static func is_editing() -> bool:
	return _current_mode() == GameModeType.EDIT
