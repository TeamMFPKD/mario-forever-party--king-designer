extends Control

## 内置头像选择器：只有一个头像预览，点它弹出选择面板（AvatarPicker）。
##
## 选中结果直接写进 MPManager.player.avatar_id，开房 / 进房时随玩家信息一起同步，
## 并保存到 GameConfig，下次启动沿用。
##
## 组织页与加入页各摆一份，两边都从 MPManager 读当前值，
## 所以来回切页面时显示保持一致（页面重新可见时会自动同步一次）。

const GameConfigType: GDScript = preload("res://script/utils/game_config.gd")
const PICKER_SCENE: PackedScene = preload("res://object/multiplayer/avatar/avatar_picker.tscn")

## 盖在预览上方、负责接收点击的透明按钮（在场景里与 Preview 重叠摆放）。
@export var avatar_button: Button
@export var avatar_texture: TextureRect
@export var avatar_initial: Label
@export var preview_ring: Panel

var _multiplayer_manager: MultiplayerManager
var _game_config: GameConfigType
var _picker: AvatarPicker


func _ready() -> void:
	_multiplayer_manager = MPManager
	_game_config = get_tree().get_first_node_in_group("game_config")
	if avatar_button != null:
		avatar_button.pressed.connect(_open_picker)
	visibility_changed.connect(_refresh)
	# 名单变化时自己的排位可能变（有人进出房间），预览圆环颜色要跟着刷新
	_multiplayer_manager.players_updated.connect(_refresh)
	_ensure_local_avatar()
	_refresh()


## 点预览：弹出选择面板，所有头像从点击位置飞出来。
func _open_picker() -> void:
	if _picker != null and is_instance_valid(_picker):
		_picker.queue_free()
		_picker = null

	# 挂到当前场景根，保证盖住整个界面（title.tscn 的根是 Node2D，用 Node 即可）。
	# current_scene 在探针或手动 add_child 的场景里可能为 null，回退到 root。
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root

	var picker: AvatarPicker = PICKER_SCENE.instantiate() as AvatarPicker
	host.add_child(picker)
	picker.z_index = 100
	_picker = picker
	_picker.avatar_chosen.connect(_on_avatar_chosen)
	_picker.picker_closed.connect(_on_picker_closed)

	var from: Vector2 = avatar_button.get_global_rect().get_center()
	_picker.open(from, _current_id())


func _on_avatar_chosen(avatar_id: String) -> void:
	_set_local_avatar(avatar_id)
	_refresh()


func _on_picker_closed() -> void:
	if _picker != null and is_instance_valid(_picker):
		_picker.queue_free()
	_picker = null


## 本地玩家当前选中的头像 id（空串表示没有可选头像，或还没选过）
func _current_id() -> String:
	return _multiplayer_manager.player.avatar_id


## 选中的头像在本端清单里不存在时（首次启动、素材被替换）回落到默认头像
func _ensure_local_avatar() -> void:
	if Avatars.index_of(_current_id()) >= 0:
		return
	_set_local_avatar(Avatars.default_id())


func _set_local_avatar(avatar_id: String) -> void:
	if _current_id() == avatar_id:
		return
	_multiplayer_manager.player.avatar_id = avatar_id
	# 测试启动不写全局配置：同机多实例会并发覆盖同一个 user://game_settings.cfg
	if _game_config and not MpTest.is_test_launch():
		_game_config.set_avatar_id(avatar_id)


func _refresh() -> void:
	var texture: Texture2D = Avatars.get_texture_by_id(_current_id())
	avatar_texture.texture = texture
	avatar_texture.visible = texture != null
	avatar_initial.visible = texture == null
	# 预览的圆环用自己在本局的身份色（1P 白 / 2P 红 …，见 PlayerColor）
	AvatarRing.paint(preview_ring, _multiplayer_manager.player_color(_multiplayer_manager.player.id))
