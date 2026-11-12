extends Control

## 通知弹窗的视觉表现层（notice_manager.gd 负责内容与显隐）。
##
## 动画（整块面板从屏幕上方掉落至屏幕中央，落位后向上反弹两次）
## 由公共组件 DropInAnimation 提供；标题页「组织游戏 / 加入游戏」面板
## 用的是同一份实现，参数改一处两边同步。
##
## 说明：
## - 位移作用在 DropRoot 上，而不是 CenterContainer 本身，这样居中布局不受影响；
## - 用 process_mode = ALWAYS，保证 get_tree().paused 时动画照常播放。

var _drop_in: DropInAnimation


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_drop_in = DropInAnimation.new()
	_drop_in.name = "DropInAnimation"
	_drop_in.target_path = ^"../DropRoot"
	_drop_in.panel_path = ^"../DropRoot/CenterContainer/UiPanel"
	# 显隐由 notice_manager.gd 控制，show_notice() 会显式调用 play_drop_in()
	_drop_in.watch_path = ^""
	add_child(_drop_in)


## 播放掉落 + 两次反弹。重复调用会先掐掉上一次动画再从头播。
func play_drop_in() -> void:
	if _drop_in != null:
		_drop_in.play_drop_in()


## 立即停止动画并把位移归零（关闭弹窗时调用）。
func stop_animation() -> void:
	if _drop_in != null:
		_drop_in.stop_animation()
