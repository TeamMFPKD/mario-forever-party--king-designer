extends Control

## 标题画面的水管入口排布。
## 五根水管是 ui/title/pipe_menu.tscn 里摆好的场景实例（Pipe0~Pipe4），
## 本脚本做四件事：视口变化时重新贴底居中、把每根的 pipe_pressed 接到对应目标、
## 页面打开时让水管从左往右依次滑出屏幕底部、页面关闭后再依次升回来。
##
## 水管用 z_index 压在页面面板之上（见 room/title.tscn 的 PipeMenu 实例），
## 否则滑出过程会被整页面板挡住；滑动期间所有管口都不再接收点击与 hover。

const PIPE_W: float = 190.0
const PIPE_GAP: float = 24.0
const PIPE_VISIBLE_H: float = 296.0
const MIN_CANVAS: Vector2 = Vector2(1920.0, 1080.0)

## 这些页面打开时把水管收起来：HostPage / JoinPage / PlayerPage 的面板会压到画面底部，
## Options 是整页设置，也一并收起。
## 注意这里的 visible 判断天然满足"退出动画播完才升回"：旧页面在退出动画期间仍是可见的。
const HIDDEN_BY: Array[String] = ["HostPage", "JoinPage", "PlayerPage", "Options"]

## 滑出/收回：逐根错开，看起来是从左往右一根接一根地走（整排 0.16 秒内走完）
const SLIDE_DURATION: float = 0.08
const SLIDE_STAGGER: float = 0.02
## 越过屏幕下沿的余量，保证管口完全看不见
const SLIDE_EXTRA: float = 24.0
## 收起时相对静止位置要往下挪多少
const SLIDE_OUT_DISTANCE: float = PIPE_VISIBLE_H + SLIDE_EXTRA

@export var host_visible_set: NodePath
@export var join_visible_set: NodePath
@export var history_jump: NodePath
@export var raid_jump: NodePath
@export var options_visible_set: NodePath

var _pipes: Array[Control] = []
## 每根水管的静止 y（贴底那一排），滑出动画的目标由它加偏移算出
var _base_tops: PackedFloat32Array = PackedFloat32Array()
## 页面打开状态：true 表示水管应该在屏幕外
var _hidden: bool = false
var _tween: Tween


func _ready() -> void:
	_pipes.clear()
	_base_tops.clear()
	for index: int in range(5):
		var pipe: Node = get_node_or_null("Pipe%d" % index)
		if pipe == null:
			continue
		_pipes.append(pipe as Control)
		_base_tops.append(0.0)
		if pipe.has_signal("pipe_pressed"):
			pipe.connect("pipe_pressed", _on_pipe_pressed)

	_hidden = _any_page_open()
	_relayout()
	resized.connect(_relayout)
	_set_input_locked(_hidden)
	for page_name: String in HIDDEN_BY:
		var page: Node = get_node_or_null("../" + page_name)
		if page is CanvasItem:
			(page as CanvasItem).visibility_changed.connect(_on_page_visibility_changed)


## 仅供截图/调试：把五根管口的道具一次性升起来
func show_all_items() -> void:
	for pipe: Control in _pipes:
		if pipe.has_method("show_item"):
			pipe.call("show_item")


func _any_page_open() -> bool:
	for page_name: String in HIDDEN_BY:
		var page: CanvasItem = get_node_or_null("../" + page_name) as CanvasItem
		if page != null and page.visible:
			return true
	return false


func _on_page_visibility_changed() -> void:
	# 一次点击可能连着改好几个节点的 visible，等这一帧改完再统一判断
	call_deferred("_sync_hidden_state")


func _sync_hidden_state() -> void:
	var hidden: bool = _any_page_open()
	if hidden == _hidden:
		return
	_hidden = hidden
	if hidden:
		_play_slide_out()
	else:
		_play_slide_in()


func _play_slide_out() -> void:
	_set_input_locked(true)
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	for index: int in range(_pipes.size()):
		_tween.tween_property(
			_pipes[index], "position:y", _base_tops[index] + SLIDE_OUT_DISTANCE, SLIDE_DURATION
		).set_delay(float(index) * SLIDE_STAGGER).set_trans(Tween.TRANS_QUAD).set_ease(
			Tween.EASE_IN
		)


func _play_slide_in() -> void:
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	for index: int in range(_pipes.size()):
		_tween.tween_property(
			_pipes[index], "position:y", _base_tops[index], SLIDE_DURATION
		).set_delay(float(index) * SLIDE_STAGGER).set_trans(Tween.TRANS_CUBIC).set_ease(
			Tween.EASE_OUT
		)
	# 全部归位后才重新接收点击，避免玩家点到还在半空的水管
	_tween.chain().tween_callback(_set_input_locked.bind(false))


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _apply_rest_positions() -> void:
	var offset: float = SLIDE_OUT_DISTANCE if _hidden else 0.0
	for index: int in range(_pipes.size()):
		_pipes[index].position.y = _base_tops[index] + offset


func _set_input_locked(locked: bool) -> void:
	for pipe: Control in _pipes:
		if pipe.has_method("set_input_locked"):
			pipe.call("set_input_locked", locked)


func _relayout() -> void:
	var canvas: Vector2 = size
	if canvas.x < MIN_CANVAS.x or canvas.y < MIN_CANVAS.y:
		canvas = Vector2(maxf(canvas.x, MIN_CANVAS.x), maxf(canvas.y, MIN_CANVAS.y))
	var total_width: float = PIPE_W * float(_pipes.size()) + PIPE_GAP * float(maxi(_pipes.size() - 1, 0))
	var left: float = (canvas.x - total_width) * 0.5
	var top: float = canvas.y - PIPE_VISIBLE_H
	for index: int in range(_pipes.size()):
		var pipe: Control = _pipes[index]
		_base_tops[index] = top
		pipe.position = Vector2(left + float(index) * (PIPE_W + PIPE_GAP), top)
		if pipe.has_method("set_base_position"):
			pipe.call("set_base_position", top)
	# 动画进行中不要打断，等动画自己把位置写完
	if _tween == null or not _tween.is_valid():
		_apply_rest_positions()


func _on_pipe_pressed(index: int) -> void:
	match index:
		0:
			_set_input_locked(true)
			_call_node(host_visible_set, "_set_visible")
		1:
			_set_input_locked(true)
			_call_node(join_visible_set, "_set_visible")
		2:
			_call_node(history_jump, "jump_to_scene")
		3:
			_call_node(raid_jump, "jump_to_scene")
		4:
			_set_input_locked(true)
			_call_node(options_visible_set, "_set_visible")


func _call_node(path: NodePath, method: StringName) -> void:
	if path.is_empty():
		return
	var node: Node = get_node_or_null(path)
	if node == null:
		push_warning("PipeMenu: 找不到目标节点 %s" % path)
		return
	node.call(method)
