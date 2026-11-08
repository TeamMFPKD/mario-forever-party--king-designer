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
		var avatar_rect: TextureRect = player_list_line.get_node("PlayerAvatar/Texture") as TextureRect
		avatar_rect.texture = avatar_texture
		avatar_rect.visible = avatar_texture != null
		var avatar_initial: Label = player_list_line.get_node("PlayerAvatar/Initial") as Label
		avatar_initial.visible = avatar_texture == null
		avatar_initial.text = profile.name.substr(0, 1)

		# 头像外圈用玩家身份色，与消息气泡同一套分配（见 PlayerColor）
		var avatar_ring: Panel = player_list_line.get_node("PlayerAvatar/Ring") as Panel
		AvatarRing.paint(avatar_ring, MPManager.player_color(profile.id))

		var player_ready_node: Control = player_list_line.get_node("PlayerReady") as Control
		player_ready_node.visible = profile.lobby_ready
		if profile.lobby_ready:
			ready_sound_node.play()
		add_child(player_list_line)
