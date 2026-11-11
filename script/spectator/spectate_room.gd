extends Control

@warning_ignore_start("unsafe_call_argument")

## 观看场景。
##
## PLAY：实例化 play_room_base 的关卡视图，去掉玩家/计时/截图等玩家逻辑，
##       只保留地形、物件、幽灵和相机；相机跟随当前目标的幽灵。
## EDIT/TRANSFER：显示等待/阶段提示。
## RESULT：由 MatchFlowService 统一切到结果房间。

const PLAY_BASE: PackedScene = preload("res://room/base/play_room_base.tscn")
const STRIP_PATHS: Array[String] = [
	"TimeoutManager",
	"BgmManager",
	"GameRoomSize/GameTimeHUD",
	"GameRoomSize/SubViewportContainer/SubViewport/RandomCapture",
	"GameRoomSize/MarginContainer",
	"MobileControlManager",
	"GameRoomSize/SubViewportContainer/SubViewport/Level/SaveLevel",
]

@onready var _target_name: Label = $Hud/InfoPanel/VBox/TargetName
@onready var _progress_label: Label = $Hud/InfoPanel/VBox/ProgressLabel
@onready var _progress: Label = $Hud/InfoPanel/VBox/Progress
@onready var _background: Parallax2D = $Background
@onready var _border: TextureRect = $BorderFrame
@onready var _waiting: VBoxContainer = $Hud/ProgressBox
@onready var _waiting_status: Label = $Hud/ProgressBox/StatusLabel
@onready var _progress_row: HBoxContainer = $Hud/ProgressBox/ProgressRow
@onready var _editor_view: TextureRect = $Hud/EditorView

var _base: Node = null
var _base_border: TextureRect = null
var _camera: LevelCamera = null
var _ghosts: MpAniSpriteManager = null
var _loaded_level: int = -1
var _editor_target_id: int = 0


func _ready() -> void:
	MPManager.phase_changed.connect(_on_phase_changed)
	MPManager.players_updated.connect(_on_players_updated)
	if MPManager.editor_stream != null:
		MPManager.editor_stream.connect("frame_received", _on_editor_frame)
	_rebuild()
	if MpTest.has("--spectate-shot"):
		_capture_spectate_shot()


func _capture_spectate_shot() -> void:
	await get_tree().create_timer(4.0).timeout
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		var path: String = "res://tools/editor_spectate.png"
		if MPManager.net != null and MPManager.net.is_server():
			path = "res://tools/editor_spectate_host.png"
		image.save_png(path)
		Log.i("SpectateRoom", "editor screenshot saved: %s" % path)
	get_tree().quit()


func _on_phase_changed(_phase: int, _payload: Dictionary) -> void:
	_rebuild()


func _on_players_updated() -> void:
	var target: PlayerProfile = _current_target()
	if target == null:
		_rebuild()
		return
	if _base == null or target.current_level != _loaded_level:
		_rebuild()
	else:
		_refresh_hud()


func _watchable() -> Array[PlayerProfile]:
	var result: Array[PlayerProfile] = []
	for profile: PlayerProfile in MPManager.players:
		if profile.is_spectator or profile.reach_end or profile.is_in_result:
			continue
		if profile.abandoned:
			continue
		if profile.id == MPManager.player.id:
			continue
		result.append(profile)
	return result


func _current_target() -> PlayerProfile:
	var list: Array[PlayerProfile] = _watchable()
	if list.is_empty():
		return null
	for profile: PlayerProfile in list:
		if profile.id == MPManager.spectate_target_id:
			return profile
	MPManager.spectate_target_id = list[0].id
	return list[0]


func _rebuild() -> void:
	_clear_view()
	_refresh_hud()
	if MPManager.phase == RoomPhase.Phase.EDIT:
		# 编辑阶段：左上角「编辑中」+ 目标编辑器画布；没有帧前不显示中央说明。
		_waiting.visible = false
		_sync_editor_watch()
		return
	_editor_view.visible = false
	_editor_view.texture = null
	_sync_editor_watch()
	if MPManager.phase != RoomPhase.Phase.PLAY:
		_waiting_status.text = _phase_text()
		# 关卡接收进度与准备人数只在传输阶段显示（文案与数值复用传输房间）。
		_progress_row.visible = MPManager.phase == RoomPhase.Phase.TRANSFER
		_waiting.visible = true
		return

	var target: PlayerProfile = _current_target()
	if target == null:
		_waiting_status.text = tr("暂时没有可观看的玩家")
		_progress_row.visible = false
		_waiting.visible = true
		return

	_loaded_level = target.current_level
	MPManager.current_level_count = _loaded_level
	_background.visible = false
	_border.visible = false
	_waiting.visible = false

	var base: Node = PLAY_BASE.instantiate()
	_strip(base)

	var load_level: LoadLevel = base.get_node_or_null(
		"GameRoomSize/SubViewportContainer/SubViewport/Level/LoadLevel"
	) as LoadLevel
	if load_level != null:
		load_level.report_progress = false

	var object_map: ObjectMapLayer = base.get_node_or_null(
		"GameRoomSize/SubViewportContainer/SubViewport/Level/ObjectMapLayer"
	) as ObjectMapLayer
	if object_map != null:
		object_map.spawn_player = false

	_ghosts = base.get_node_or_null(
		"GameRoomSize/SubViewportContainer/SubViewport/Level/MultiplayerAniSpriteManager"
	) as MpAniSpriteManager
	if _ghosts != null:
		_ghosts.spectate_mode = true

	_camera = base.get_node_or_null(
		"GameRoomSize/SubViewportContainer/SubViewport/Level/LevelCamera"
	) as LevelCamera

	add_child(base)
	move_child(base, 0)
	_base = base
	_base_border = base.get_node_or_null(
		"GameRoomSize/SubViewportContainer/Node2D/GameBorderTextureRect"
	) as TextureRect
	_apply_target_color()


func _strip(base: Node) -> void:
	for path: String in STRIP_PATHS:
		var node: Node = base.get_node_or_null(path)
		if node == null:
			continue
		node.get_parent().remove_child(node)
		node.free()


func _clear_view() -> void:
	_camera = null
	_ghosts = null
	_base_border = null
	if _base != null and is_instance_valid(_base):
		_base.queue_free()
	_base = null
	_background.visible = true
	_border.visible = true
	_waiting.visible = true


## 前端演示场景用来驱动一个假幽灵。
func get_ghost_manager() -> MpAniSpriteManager:
	return _ghosts


func _process(_delta: float) -> void:
	if _ghosts == null or _camera == null:
		return
	var target: PlayerProfile = _current_target()
	if target == null:
		return
	for ani: AnimatedSprite2D in _ghosts.anis:
		var is_target: bool = ani.has_meta("player_id") \
			and int(ani.get_meta("player_id")) == target.id
		# 被观测玩家完全不透明；同房间其他玩家保留半透明幽灵。
		ani.self_modulate = Color(1, 1, 1, 1.0 if is_target else 0.25)
		ani.z_index = 10 if is_target else 9
	var ghost: AnimatedSprite2D = _ghosts.get_ghost(target.id)
	if ghost != null and _camera.player != ghost:
		_camera.player = ghost
		_camera.reset_physics_interpolation()


func _phase_text() -> String:
	match MPManager.phase:
		RoomPhase.Phase.EDIT:
			return tr("编辑中")
		RoomPhase.Phase.TRANSFER:
			# 与关卡传输房间的提示文案保持一致。
			return tr("传输 / 接收关卡数据中……")
		RoomPhase.Phase.PLAY:
			return tr("等待其他玩家完成…")
		RoomPhase.Phase.RESULT:
			return tr("结算中…")
		_:
			return tr("等待房间开始…")


func _input(event: InputEvent) -> void:
	if MPManager.phase != RoomPhase.Phase.PLAY \
	and MPManager.phase != RoomPhase.Phase.EDIT:
		return
	if event.is_action_pressed("move_left"):
		_switch_target(-1)
	elif event.is_action_pressed("move_right"):
		_switch_target(1)
	else:
		return
	get_viewport().set_input_as_handled()


func _switch_target(step: int) -> void:
	var list: Array[PlayerProfile] = _watchable()
	if list.size() <= 1:
		return
	var index: int = 0
	for i: int in range(list.size()):
		if list[i].id == MPManager.spectate_target_id:
			index = i
			break
	index = (index + step + list.size()) % list.size()
	MPManager.spectate_target_id = list[index].id
	var target: PlayerProfile = list[index]
	if MPManager.phase == RoomPhase.Phase.EDIT:
		# 编辑阶段换人：只换截图订阅目标。
		_refresh_hud()
		_apply_target_color()
		_sync_editor_watch()
		return
	if _base != null and target.current_level == _loaded_level:
		# 同一关内换人：不重新加载关卡，只换相机/高亮/边框颜色。
		_refresh_hud()
		_apply_target_color()
	else:
		_rebuild()


## 编辑阶段：订阅当前目标的编辑器截图。目标为空则取消订阅。
func _sync_editor_watch() -> void:
	if MPManager.editor_stream == null:
		return
	if MPManager.phase != RoomPhase.Phase.EDIT:
		if _editor_target_id != 0:
			_editor_target_id = 0
			_editor_view.visible = false
			_editor_view.texture = null
			MPManager.editor_stream.call("clear_local_watch")
		return
	var target: PlayerProfile = _current_target()
	var target_id: int = 0 if target == null else target.id
	if target_id == _editor_target_id:
		return
	_editor_target_id = target_id
	_editor_view.texture = null
	_editor_view.visible = false
	if target_id == 0:
		MPManager.editor_stream.call("clear_local_watch")
	else:
		MPManager.editor_stream.call("request_watch", target_id)


func _on_editor_frame(jpeg: PackedByteArray) -> void:
	if MPManager.phase != RoomPhase.Phase.EDIT:
		return
	var image: Image = Image.new()
	if image.load_jpg_from_buffer(jpeg) != OK:
		return
	_editor_view.texture = ImageTexture.create_from_image(image)
	_editor_view.visible = true


## 只给关卡边框上玩家身份色；左上信息面板保持固定的深紫底、无描边、不随目标改色。
func _apply_target_color() -> void:
	var target: PlayerProfile = _current_target()
	var color: Color = Color(1, 1, 1, 1)
	if target != null:
		color = MPManager.player_color(target.id)
	_border.self_modulate = color
	if _base_border != null and is_instance_valid(_base_border):
		_base_border.self_modulate = color


func _refresh_hud() -> void:
	var target: PlayerProfile = _current_target()
	if target != null:
		_target_name.text = target.name
	else:
		_target_name.text = "-"

	if MPManager.phase == RoomPhase.Phase.EDIT:
		# EDIT 阶段用「编辑中」替换「关卡进度：x/y」整块内容。
		_progress_label.visible = false
		_progress.text = tr("编辑中")
	else:
		_progress_label.visible = true
		if target != null:
			var total: int = MPManager.total_levels
			_progress.text = "-/-" if total <= 0 else "%d/%d" % [
				clampi(target.current_level + 1, 1, total),
				total,
			]
		else:
			_progress.text = "-/-"
	_apply_target_color()
