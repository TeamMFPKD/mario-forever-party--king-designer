extends Node

## 大厅“开始游戏”按钮。
## 只负责收集编辑时长并转交 LobbyService，场景切换由 MatchFlowService 统一处理。

@export var bar: HScrollBar

var config: ConfigFile
var _start_button: Button


func _ready() -> void:
	config = GameConfig.config
	_setup_start_button.call_deferred()


func _setup_start_button() -> void:
	_start_button = get_node_or_null(
		"../GameRoomSize/PlayerPage/UiPanel/UiMarginContainer/VBoxContainer/HBoxContainer/StartButton"
	) as Button
	if _start_button == null:
		return
	MPManager.players_updated.connect(_refresh_start_button)
	MPManager.phase_changed.connect(_on_phase_changed)
	_refresh_start_button()


func _on_phase_changed(_phase: int, _payload: Dictionary) -> void:
	_refresh_start_button()


## 0 名游玩玩家（全是观战者）时禁止开始；非房主不显示开始按钮。
func _refresh_start_button() -> void:
	if _start_button == null:
		return
	var is_host: bool = MPManager.net.is_server()
	_start_button.visible = is_host
	_start_button.disabled = not is_host or MPManager.lobby.playing_count() <= 0


func _on_start_button_pressed() -> void:
	var manager: MultiplayerManager = MPManager
	if not manager.net.is_server():
		return
	if manager.lobby.playing_count() <= 0:
		Notice.show_notice("至少需要 1 名游玩玩家才能开始。", "无法开始")
		return
	var edit_seconds: int = int(bar.value)
	config.set_value("game_settings", "host_set_edit_time_limit", edit_seconds)
	GameConfig.save()
	manager.lobby.request_start(edit_seconds)
