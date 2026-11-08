extends Node

## 进入结算房间时告诉主机“我已玩完所有关卡”。
## 结算数据由主机统一计算并广播，本脚本不再本地轮询、不再自行算分。


func _ready() -> void:
	MPManager.flow.notify_reach_end()
