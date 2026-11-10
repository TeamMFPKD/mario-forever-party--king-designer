extends VBoxContainer

@export var player_list_scene: PackedScene
@export var path_to_ready_sound_node: NodePath = "../ReadySound"

var players: Array[PlayerProfile] = []
var ready_sound_node: AudioStreamPlayer
var _player_page: Control


func _ready() -> void:
	MPManager.players_updated.connect(_on_players_updated)
	ready_sound_node = get_node(path_to_ready_sound_node) as AudioStreamPlayer
	_player_page = _find_player_page()
	if _player_page != null:
		# 子节点的 visibility_changed 不会随父页面显隐触发，这里监听 PlayerPage 本身。
		_player_page.visibility_changed.connect(_on_page_visibility_changed)
	# 清掉 tscn 里用于排版预览的占位行（它的名字不是真实玩家）。
	_on_players_updated()


func _find_player_page() -> Control:
	var node: Node = self
	while node != null:
		if node is Control and node.name == "PlayerPage":
			return node as Control
		node = node.get_parent()
	return null


func _on_page_visibility_changed() -> void:
	if _player_page != null and _player_page.visible:
		MPManager.lobby.request_roster()
		_on_players_updated()


func _on_players_updated() -> void:
	players = MPManager.players

	# Clear
	for child: Node in get_children():
		child.free()

	# Re-add
	var player_number: int = 1
	for profile: PlayerProfile in players:
		var player_list_line: Node = player_list_scene.instantiate()
		var player_id_label: Label = player_list_line.get_node("PlayerIdLabel") as Label
		player_id_label.text = str(player_number)
		player_number += 1

		var player_name_label: Label = player_list_line.get_node("PlayerNameLabel") as Label
		player_name_label.text = profile.name

		# 内置头像：取不到时回退到名字首字（与消息气泡一致）
		var avatar_texture: Texture2D = Avatars.get_texture_by_id(profile.avatar_id)
		var avatar_rect: TextureRect = player_list_line.get_node("PlayerAvatarRect/PlayerAvatar/Texture") as TextureRect
		avatar_rect.texture = avatar_texture
		avatar_rect.visible = avatar_texture != null
		var avatar_initial: Label = player_list_line.get_node("PlayerAvatarRect/PlayerAvatar/Initial") as Label
		avatar_initial.visible = avatar_texture == null
		avatar_initial.text = profile.name.substr(0, 1)

		# 头像外圈用玩家身份色，与消息气泡同一套分配（见 PlayerColor）
		var avatar_ring: Panel = player_list_line.get_node("PlayerAvatarRect/PlayerAvatar/Ring") as Panel
		AvatarRing.paint(avatar_ring, MPManager.player_color(profile.id))

		# 参与模式：角色徽章本身就是按钮；只有本地玩家可点击切换。
		var role_button: Button = player_list_line.get_node("PlayerRoleButton") as Button
		var is_local: bool = profile.id == MPManager.player.id
		role_button.text = tr("观战") if profile.is_spectator else tr("游戏")
		# 已准备后锁定参与模式；非本地玩家只作为徽章显示。
		role_button.disabled = not is_local \
			or MPManager.phase != RoomPhase.Phase.LOBBY \
			or profile.lobby_ready
		var role_style: StyleBoxFlat = StyleBoxFlat.new()
		role_style.bg_color = Color("3d6fe0") if profile.is_spectator else Color("2f9e6e")
		role_style.set_corner_radius_all(8)
		role_style.content_margin_left = 10.0
		role_style.content_margin_right = 10.0
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			role_button.add_theme_stylebox_override(state, role_style)
		if is_local:
			role_button.pressed.connect(_on_role_button_pressed)

		var player_ready_node: Control = player_list_line.get_node("PlayerReady") as Control
		player_ready_node.visible = profile.lobby_ready and not profile.is_spectator
		if profile.lobby_ready and not profile.is_spectator:
			# 重连时名单快照可能在标题界面之外到达，节点不在树里不能播放。
			if ready_sound_node != null and ready_sound_node.is_inside_tree():
				ready_sound_node.play()
		add_child(player_list_line)


func _on_role_button_pressed() -> void:
	MPManager.set_local_spectator(not MPManager.player.is_spectator)
