extends Button

## 编辑房间的“制作完毕！”按钮（爆炸星底纹见 ready_burst.gd，按按钮尺寸实时绘制）。
## 本地玩家点击后上报主机；当房间内所有玩家都完成编辑时，
## 主机提前结束倒计时，直接进入关卡传输房间（MPManager.edit_all_ready）。

var multiplayer_manager: MultiplayerManager
@onready var _burst: Control = get_node_or_null("Burst") as Control

func _ready() -> void:
	multiplayer_manager = MPManager
	pressed.connect(_on_button_pressed)
	multiplayer_manager.players_updated.connect(_refresh)
	_refresh()

func _on_button_pressed() -> void:
	var local_player: Dictionary = _get_local_player()
	var local_finished: bool = local_player.get("is_ready_to_finish", false)
	if local_player.is_empty() or local_finished:
		return
	# 先锁住按钮，避免重复上报；主机同步玩家列表后会刷新真实状态
	disabled = true
	_set_burst_dimmed(true)
	multiplayer_manager.set_edit_ready.rpc(multiplayer_manager.player.id, true)

func _get_local_player() -> Dictionary:
	for p: Dictionary in multiplayer_manager.players:
		if p.id == multiplayer_manager.player.id:
			return p
	return {}

func _refresh() -> void:
	var local_player: Dictionary = _get_local_player()
	if local_player.is_empty():
		# 没有加入多人房间（例如直接运行编辑场景）时不需要准备
		visible = false
		return
	visible = true
	var ready_count: int = 0
	for p: Dictionary in multiplayer_manager.players:
		var player_finished: bool = p.get("is_ready_to_finish", false)
		if player_finished:
			ready_count += 1
	var is_ready: bool = local_player.get("is_ready_to_finish", false)
	disabled = is_ready
	_set_burst_dimmed(is_ready)
	text = "制作完毕！（%d/%d）" % [ready_count, multiplayer_manager.players.size()]

func _set_burst_dimmed(dimmed: bool) -> void:
	if _burst == null:
		return
	var color: Color = Color(0.7, 0.7, 0.7, 0.85) if dimmed else Color(1, 1, 1, 1)
	_burst.modulate = color
