extends Button

## 编辑房间的“制作完毕！”按钮。
## 当前按钮改用和普通按钮一致的淡黄色矩形（主题样式见 edit.tscn 的 theme_override_styles），
## 爆炸星底纹（ready_burst.gd）已停用：Burst 节点还在场景里但被隐藏，绘制代码保留备用。
## 本地玩家点击后上报主机；当房间内所有玩家都完成编辑时，
## 主机提前结束倒计时，直接进入关卡传输房间。

var _burst: ReadyBurst
var _hovered: bool = false


func _ready() -> void:
	_burst = _find_burst()
	pressed.connect(_on_button_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	MPManager.players_updated.connect(_refresh)
	_refresh()


func _on_button_pressed() -> void:
	var local_player: PlayerProfile = MPManager.get_local_player()
	if local_player.edit_finished:
		return
	# 先锁住按钮，避免重复上报；主机同步后会刷新真实状态
	disabled = true
	_update_burst_state()
	MPManager.lobby.set_edit_finished(true)


func _on_mouse_entered() -> void:
	_hovered = true
	_update_burst_state()


func _on_mouse_exited() -> void:
	_hovered = false
	_update_burst_state()


func _refresh() -> void:
	var local_player: PlayerProfile = MPManager.get_local_player()
	if local_player == null or local_player.id == 0:
		# 没有加入多人房间（例如直接运行编辑场景）时不需要准备
		_set_shown(false)
		return
	_set_shown(true)
	var ready_count: int = 0
	for profile: PlayerProfile in MPManager.players:
		if profile.edit_finished:
			ready_count += 1
	disabled = local_player.edit_finished
	_update_burst_state()
	text = "制作完毕！（%d/%d）" % [ready_count, MPManager.players.size()]


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
