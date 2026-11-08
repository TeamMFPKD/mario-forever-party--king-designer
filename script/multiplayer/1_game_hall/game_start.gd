extends Node

## 大厅“开始游戏”按钮。
## 只负责收集编辑时长并转交 LobbyService，场景切换由 MatchFlowService 统一处理。

@export var bar: HScrollBar

var config: ConfigFile


func _ready() -> void:
	config = GameConfig.config


func _on_start_button_pressed() -> void:
	var manager: MultiplayerManager = MPManager
	if not manager.net.is_server():
		return
	var edit_seconds: int = int(bar.value)
	config.set_value("game_settings", "host_set_edit_time_limit", edit_seconds)
	GameConfig.save()
	manager.lobby.request_start(edit_seconds)
