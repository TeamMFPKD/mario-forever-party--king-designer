extends MarginContainer

class_name SpectateTimeHUD

## 观看场景右上角的计时。只负责显示，数值由 spectate_room.gd 按阶段算好喂进来：
## - EDIT：编辑倒计时（房间级倒计时，不是测试关卡内部的计时器）；
## - PLAY：被观看玩家在其关卡内的剩余时间。
##
## 版式对齐游玩房间的 GameTimeHUD（233×233、字号 120、黑色描边 18），
## 两者在各自房间里都贴在 1920×1080 游戏区的右上角。

## 剩不到这么多秒时转黄，与编辑房间 TimeHUD 的告警一致。
const WARNING_SECONDS: float = 10.0

@onready var _label: Label = $TimeLabel

var _shown_second: int = -1


## 显示剩余秒数（向上取整）。同一个数字只写一次文本，避免每帧重排。
func show_seconds(seconds: float) -> void:
	var value: int = maxi(0, ceili(seconds))
	if value != _shown_second:
		_shown_second = value
		_label.text = str(value)
	_label.self_modulate = Color.YELLOW if seconds <= WARNING_SECONDS else Color.WHITE
	visible = true


## 没有可显示的数值（阶段不对 / 还没收到目标的计时）：整块隐藏，
## 留空而不是显示 0，免得被当成真的没时间了。
func clear() -> void:
	visible = false
	_shown_second = -1
