extends Node

enum TileSetNames {
	CASTLE,
	CASTLE_B,
	CAVE,
	DUSK,
	NIGHT,
	OVERWORLD,
	SAND,
	SNOW,
	SNOW_B,
	VOLCANO,
}

@export var level_data_node: LevelManager

func _physics_process(_delta: float) -> void:
	if (Input.is_key_pressed(KEY_1)):
		_change_theme(LevelManager.LevelThemeEnum.CASTLE)
	elif (Input.is_key_pressed(KEY_2)):
		_change_theme(LevelManager.LevelThemeEnum.CASTLE_B)
	elif (Input.is_key_pressed(KEY_3)):
		_change_theme(LevelManager.LevelThemeEnum.CAVE)
	elif (Input.is_key_pressed(KEY_4)):
		_change_theme(LevelManager.LevelThemeEnum.DUSK)
	elif (Input.is_key_pressed(KEY_5)):
		_change_theme(LevelManager.LevelThemeEnum.NIGHT)
	elif (Input.is_key_pressed(KEY_6)):
		_change_theme(LevelManager.LevelThemeEnum.OVERWORLD)
	elif (Input.is_key_pressed(KEY_7)):
		_change_theme(LevelManager.LevelThemeEnum.SAND)
	elif (Input.is_key_pressed(KEY_8)):
		_change_theme(LevelManager.LevelThemeEnum.SNOW)
	elif (Input.is_key_pressed(KEY_9)):
		_change_theme(LevelManager.LevelThemeEnum.SNOW_B)
	elif (Input.is_key_pressed(KEY_0)):
		_change_theme(LevelManager.LevelThemeEnum.VOLCANO)

## 调试键切换主题也走命令，避免出现“不入历史、却破坏跨主题瓦片快照”的分支。
## 每帧轮询的重复调用由 create() 的同值返回 null 过滤，不会刷爆历史。
func _change_theme(target_theme: LevelManager.LevelThemeEnum) -> void:
	if level_data_node == null or level_data_node.level_theme == target_theme:
		return
	var stack: CommandStack = CommandStack.find_in(get_tree())
	if stack != null:
		var command: CmdChangeLevelTheme = CmdChangeLevelTheme.create(
			level_data_node, level_data_node.level_theme, target_theme)
		if command != null:
			stack.execute_command(command)
			return
	level_data_node.level_theme = target_theme

func _button_1_pressed() -> void:
	print("[test_node.gd] Button 1 Pressed")

func _button_2_pressed() -> void:
	print("[test_node.gd] Button 2 Pressed")
	