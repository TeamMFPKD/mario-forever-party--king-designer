extends Node

## 菜单动作门控（autoload 名：MenuGate）。
##
## 问题：需求要求「Enter / move_jump 确认、Esc / move_fire 取消」，
## 而 move_jump / move_fire 是**游戏内**的跳跃/发射键。如果直接复用，
## 游戏里按 Z 会同时触发"跳跃"和"菜单确认"。
##
## 解法：物理键绑到独立的 ui_menu_accept / ui_menu_cancel 动作（见 project.godot），
## 由本节点按当前场景决定这两个动作是否生效：
##   - 菜单 / 标题 / 暂停等界面 → 生效
##   - 游戏内（PLAY / ADVENTURE / TEST）→ 屏蔽
##
## 屏蔽方式：在 _input 阶段把事件标记为已处理，
## 后面的 _unhandled_input（MenuCursor 等）就收不到。

## 当前是否允许菜单动作
var menu_actions_enabled: bool = true


func _ready() -> void:
	# 暂停时也要能响应（暂停菜单本身要用方向键和确认）
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if menu_actions_enabled:
		return
	if event.is_action_pressed("ui_menu_accept") or event.is_action_pressed("ui_menu_cancel"):
		get_viewport().set_input_as_handled()


## 由场景主动设置。
func set_menu_actions_enabled(enabled: bool) -> void:
	menu_actions_enabled = enabled


## 按当前 GameMode 自动同步（场景 _ready 里调用一次即可）。
func sync_with_game_mode() -> void:
	menu_actions_enabled = not (
		GameMode.is_playing() or GameMode.is_adventure() or GameMode.is_testing()
	)
