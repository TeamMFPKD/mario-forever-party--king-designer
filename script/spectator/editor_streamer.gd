extends Node

## 编辑房间里的抓屏节点：只抓关卡画布 SubViewport，降频交给
## EditorStreamService 压缩/定向发送。没有观看者时不抓屏。

const CAPTURE_INTERVAL_SEC: float = 0.25

var _viewport: SubViewport
var _accum: float = 0.0


func _ready() -> void:
	# EditorStreamer 是编辑房间根节点的子节点；GameRoomSize 是它的兄弟。
	_viewport = get_node_or_null(
		"../GameRoomSize/SubViewportContainer/SubViewport"
	) as SubViewport
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		Log.i("EditorStreamer", "关卡画布绑定成功")
	else:
		Log.e("EditorStreamer", "找不到关卡 SubViewport")


func _process(delta: float) -> void:
	if _viewport == null:
		return
	if DisplayServer.get_name() == "headless":
		return
	if MPManager.phase != RoomPhase.Phase.EDIT:
		return
	var service: Node = MPManager.editor_stream
	if service == null or service.call("has_subscribers") != true:
		return
	_accum += delta
	if _accum < CAPTURE_INTERVAL_SEC:
		return
	_accum = 0.0
	var image: Image = _viewport.get_texture().get_image()
	if image == null:
		return
	service.call("push_frame", image)
