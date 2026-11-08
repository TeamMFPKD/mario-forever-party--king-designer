extends Button

## 编辑房间的“制作完毕！”按钮（爆炸星底纹见 ready_burst.gd，按按钮尺寸实时绘制）。
## 本地玩家点击后上报主机；当房间内所有玩家都完成编辑时，
## 主机提前结束倒计时，直接进入关卡传输房间（MPManager.edit_all_ready）。

var multiplayer_manager: MultiplayerManager
var _burst: ReadyBurst

var _hovered: bool = false

func _ready() -> void:
	multiplayer_manager = MPManager
	_burst = _find_burst()
	pressed.connect(_on_button_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	multiplayer_manager.players_updated.connect(_refresh)
	_refresh()

func _on_button_pressed() -> void:
	var local_player: Dictionary = _get_local_player()
	var local_finished: bool = local_player.get("is_ready_to_finish", false)
	if local_player.is_empty() or local_finished:
		return
	# 先锁住按钮，避免重复上报；主机同步玩家列表后会刷新真实状态
	disabled = true
	_update_burst_state()
	multiplayer_manager.set_edit_ready.rpc(multiplayer_manager.player.id, true)

func _on_mouse_entered() -> void:
	_hovered = true
	_update_burst_state()

func _on_mouse_exited() -> void:
	_hovered = false
	_update_burst_state()

func _get_local_player() -> Dictionary:
	for p: Dictionary in multiplayer_manager.players:
		if p.id == multiplayer_manager.player.id:
			return p
	return {}

func _refresh() -> void:
	var local_player: Dictionary = _get_local_player()
	if local_player.is_empty():
		# 没有加入多人房间（例如直接运行编辑场景）时不需要准备
		_set_shown(false)
		return
	_set_shown(true)
	var ready_count: int = 0
	for p: Dictionary in multiplayer_manager.players:
		var player_finished: bool = p.get("is_ready_to_finish", false)
		if player_finished:
			ready_count += 1
	var is_ready: bool = local_player.get("is_ready_to_finish", false)
	disabled = is_ready
	_update_burst_state()
	text = "制作完毕！（%d/%d）" % [ready_count, multiplayer_manager.players.size()]

## 底色三态：已完成 → 灰色；悬停 → 提亮 + 微放大；否则默认金黄
func _update_burst_state() -> void:
	if _burst == null:
		_burst = _find_burst()
	if _burst == null:
		return
	if disabled:
		_burst.set_state(ReadyBurst.State.DONE)
	elif _hovered:
		_burst.set_state(ReadyBurst.State.HOVER)
	else:
		_burst.set_state(ReadyBurst.State.NORMAL)

## 星形底纹既可能挂在按钮下面，也可能作为按钮的父节点（编辑器里调整过层级），两种都兼容
func _find_burst() -> ReadyBurst:
	var child: Node = get_node_or_null("Burst")
	if child is ReadyBurst:
		return child as ReadyBurst
	var parent: Node = get_parent()
	if parent is ReadyBurst:
		return parent as ReadyBurst
	return null

## Burst 作为父节点时，只隐藏按钮会留下一颗没有文字的星，所以两者一起控制显隐
func _set_shown(shown: bool) -> void:
	if _burst == null:
		_burst = _find_burst()
	if _burst != null:
		_burst.visible = shown
	visible = shown
