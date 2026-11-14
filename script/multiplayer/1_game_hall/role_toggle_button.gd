extends UiSoundButton

## 大厅“参与模式”切换按钮：显示当前角色，点击在「游戏 / 观看」之间切换。
##
## - 未进房：只改本地预选，不联网；
## - 已进房且处于 LOBBY：交给 LobbyService 广播；
## - 开局后：按钮禁用，角色锁定。
##
## 外观与玩家列表里的 PlayerRoleButton 一致：圆角矩形徽章 + 白字描边，
## 底色按角色切换（游戏薄荷绿 / 观看蓝），只是尺寸放大了点。

## 与 ui/list/player_list.tscn 的 PlayerRoleButton 同源配色
const COLOR_PLAYING: Color = Color("2f9e6e")
const COLOR_SPECTATING: Color = Color("3d6fe0")
## 玩家列表里是 140×44，大厅这行放大一号
const BADGE_SIZE: Vector2 = Vector2(210, 60)
const BADGE_FONT_SIZE: int = 28
const BADGE_OUTLINE: int = 4
const BADGE_RADIUS: int = 8


## 把按钮套成玩家列表那种圆角矩形徽章；host / join 页动态创建时调用一次即可。
static func apply_badge_style(button: Button) -> void:
	button.custom_minimum_size = BADGE_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.65))
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	button.add_theme_constant_override("outline_size", BADGE_OUTLINE)


func _ready() -> void:
	super()
	# 本机多开测试：--mp-spectate 的实例默认以观看身份启动。
	if MpTest.has("--mp-spectate"):
		MPManager.set_local_spectator(true)
	pressed.connect(_on_button_pressed)
	MPManager.local_role_changed.connect(_on_role_changed)
	MPManager.phase_changed.connect(_on_phase_changed)
	MPManager.players_updated.connect(_refresh)
	_refresh()


func _on_button_pressed() -> void:
	var local: PlayerProfile = MPManager.get_local_player()
	MPManager.set_local_spectator(local == null or not local.is_spectator)


func _on_role_changed(_is_spectator: bool) -> void:
	_refresh()


func _on_phase_changed(_phase: int, _payload: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	var local: PlayerProfile = MPManager.get_local_player()
	var is_spectator: bool = local != null and local.is_spectator
	text = tr("观看") if is_spectator else tr("游戏")
	_apply_badge_color(is_spectator)
	var online: bool = MPManager.net != null and MPManager.net.is_online()
	var locked: bool = online and (
		MPManager.phase != RoomPhase.Phase.LOBBY
		or (local != null and local.lobby_ready)
	)
	disabled = locked


## 底色跟随角色，和玩家列表里的角色徽章保持一致
func _apply_badge_color(is_spectator: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_SPECTATING if is_spectator else COLOR_PLAYING
	style.set_corner_radius_all(BADGE_RADIUS)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, style)
