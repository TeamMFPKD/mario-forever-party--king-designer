extends Node

## 关卡传输房间的“强制继续”按钮。
## 正常流程由 LevelTransferService 自动推进；这里只用于卡住时让主机重新检查一次。


func lets_play_together() -> void:
	MPManager.levels.force_continue()
