class_name CmdChangeLevelTheme
extends Command

## 关卡主题命令。
##
## 主题同时决定 TileSet、背景场景、管道颜色与图块预览，撤销 / 重做统一
## 走 LevelManager.level_theme 的 setter（update_theme + level_theme_changed），
## 由各订阅者自己还原，命令只保存主题枚举。
##
## 主题切换会替换 TileSet，但历史不再清空：撤销顺序天然保证“先撤销新主题
## 下的瓦片操作，再回到旧主题”，瓦片快照始终与当时的 TileSet 对应。
## 因此所有主题变更入口（主题按钮、调试键）都必须走本命令。

var _level_manager: LevelManager = null
var _before_theme: LevelManager.LevelThemeEnum = LevelManager.LevelThemeEnum.OVERWORLD
var _after_theme: LevelManager.LevelThemeEnum = LevelManager.LevelThemeEnum.OVERWORLD

static func create(
		level_manager: LevelManager,
		before_theme: LevelManager.LevelThemeEnum,
		after_theme: LevelManager.LevelThemeEnum
) -> CmdChangeLevelTheme:
	if level_manager == null or not is_instance_valid(level_manager):
		return null
	if before_theme == after_theme:
		return null
	var command: CmdChangeLevelTheme = CmdChangeLevelTheme.new()
	command._level_manager = level_manager
	command._before_theme = before_theme
	command._after_theme = after_theme
	return command

func get_display_name() -> String:
	return "ChangeTheme(%d)" % _after_theme

func execute() -> void:
	_apply(_after_theme)

func undo() -> void:
	_apply(_before_theme)

func is_valid() -> bool:
	return _level_manager != null and is_instance_valid(_level_manager)

func _apply(theme: LevelManager.LevelThemeEnum) -> void:
	if not is_valid() or _level_manager.level_theme == theme:
		return
	_level_manager.level_theme = theme
