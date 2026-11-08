extends HBoxContainer

## 内置头像选择器：(<) 头像预览 (>)
##
## 选中结果直接写进 MPManager.player["avatar_id"]，开房 / 进房时随玩家信息一起同步，
## 并保存到 GameConfig，下次启动沿用。
##
## 组织页与加入页各摆一份，两边都从 MPManager 读当前值，
## 所以来回切页面时显示保持一致（页面重新可见时会自动同步一次）。

const GameConfigType: GDScript = preload("res://script/utils/game_config.gd")

@export var prev_button: Button
@export var next_button: Button
@export var avatar_texture: TextureRect
@export var avatar_initial: Label

var _multiplayer_manager: MultiplayerManager
var _game_config: GameConfigType


func _ready() -> void:
	_multiplayer_manager = MPManager
	_game_config = get_tree().get_first_node_in_group("game_config")
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	visibility_changed.connect(_refresh)
	_ensure_local_avatar()
	_refresh()


func _on_prev_pressed() -> void:
	_step(-1)


func _on_next_pressed() -> void:
	_step(1)


func _step(direction: int) -> void:
	var total: int = Avatars.count()
	if total <= 0:
		return
	var index: int = Avatars.index_of(_current_id())
	if index < 0:
		index = 0
	else:
		index = wrapi(index + direction, 0, total)
	_set_local_avatar(Avatars.get_id(index))
	_refresh()


## 本地玩家当前选中的头像 id（空串表示没有可选头像，或还没选过）
func _current_id() -> String:
	var value: Variant = _multiplayer_manager.player.get("avatar_id", "")
	return str(value)


## 选中的头像在本端清单里不存在时（首次启动、素材被替换）回落到默认头像
func _ensure_local_avatar() -> void:
	if Avatars.index_of(_current_id()) >= 0:
		return
	_set_local_avatar(Avatars.default_id())


func _set_local_avatar(avatar_id: String) -> void:
	if _current_id() == avatar_id:
		return
	_multiplayer_manager.player["avatar_id"] = avatar_id
	# 测试启动不写全局配置：同机多实例会并发覆盖同一个 user://game_settings.cfg
	if _game_config and not MpTest.is_test_launch():
		_game_config.set_avatar_id(avatar_id)


func _refresh() -> void:
	var texture: Texture2D = Avatars.get_texture_by_id(_current_id())
	avatar_texture.texture = texture
	avatar_texture.visible = texture != null
	avatar_initial.visible = texture == null
	# 0 或 1 个头像时没有可切换的对象
	var switchable: bool = Avatars.count() > 1
	prev_button.disabled = not switchable
	next_button.disabled = not switchable
