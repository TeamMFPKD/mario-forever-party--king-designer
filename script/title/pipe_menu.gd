extends Control

## 标题画面的水管入口排布。
## 五根水管是 ui/title/pipe_menu.tscn 里摆好的场景实例（Pipe0~Pipe4），
## 本脚本只做三件事：视口变化时重新贴底居中、把每根的 pipe_pressed 接到对应目标、给截图用的展开接口。

const PIPE_W: float = 190.0
const PIPE_GAP: float = 24.0
const PIPE_VISIBLE_H: float = 296.0
const MIN_CANVAS: Vector2 = Vector2(1920.0, 1080.0)

## 这些页面打开时把水管收起来：HostPage / JoinPage 的面板一直压到画面底部，
## 会和贴底的水管叠在一起；Options 是整页设置，面板只占中间，不用动水管。
const HIDDEN_BY: Array[String] = ["HostPage", "JoinPage"]

@export var host_visible_set: NodePath
@export var join_visible_set: NodePath
@export var history_jump: NodePath
@export var raid_jump: NodePath
@export var options_visible_set: NodePath

var _pipes: Array[Control] = []


func _ready() -> void:
	_pipes.clear()
	for index: int in range(5):
		var pipe: Node = get_node_or_null("Pipe%d" % index)
		if pipe == null:
			continue
		_pipes.append(pipe as Control)
		if pipe.has_signal("pipe_pressed"):
			pipe.connect("pipe_pressed", _on_pipe_pressed)
	_relayout()
	resized.connect(_relayout)
	for page_name: String in HIDDEN_BY:
		var page: Node = get_node_or_null("../" + page_name)
		if page is CanvasItem:
			(page as CanvasItem).visibility_changed.connect(_refresh_visible)
	_refresh_visible()


## 有浮层面板打开时整排水管隐藏，关掉后恢复
func _refresh_visible() -> void:
	for page_name: String in HIDDEN_BY:
		var page: CanvasItem = get_node_or_null("../" + page_name) as CanvasItem
		if page != null and page.visible:
			visible = false
			return
	visible = true


## 仅供截图/调试：把五根管口的道具一次性升起来
func show_all_items() -> void:
	for pipe: Control in _pipes:
		if pipe.has_method("show_item"):
			pipe.call("show_item")


func _relayout() -> void:
	var canvas: Vector2 = size
	if canvas.x < MIN_CANVAS.x or canvas.y < MIN_CANVAS.y:
		canvas = Vector2(maxf(canvas.x, MIN_CANVAS.x), maxf(canvas.y, MIN_CANVAS.y))
	var total_width: float = PIPE_W * float(_pipes.size()) + PIPE_GAP * float(maxi(_pipes.size() - 1, 0))
	var left: float = (canvas.x - total_width) * 0.5
	var top: float = canvas.y - PIPE_VISIBLE_H
	for index: int in range(_pipes.size()):
		var pipe: Control = _pipes[index]
		pipe.position = Vector2(left + float(index) * (PIPE_W + PIPE_GAP), top)
		if pipe.has_method("set_base_position"):
			pipe.call("set_base_position", top)


func _on_pipe_pressed(index: int) -> void:
	match index:
		0:
			_call_node(host_visible_set, "_set_visible")
		1:
			_call_node(join_visible_set, "_set_visible")
		2:
			_call_node(history_jump, "jump_to_scene")
		3:
			_call_node(raid_jump, "jump_to_scene")
		4:
			_call_node(options_visible_set, "_set_visible")


func _call_node(path: NodePath, method: StringName) -> void:
	if path.is_empty():
		return
	var node: Node = get_node_or_null(path)
	if node == null:
		push_warning("PipeMenu: 找不到目标节点 %s" % path)
		return
	node.call(method)
