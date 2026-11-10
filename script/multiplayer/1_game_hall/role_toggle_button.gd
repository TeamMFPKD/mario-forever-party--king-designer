extends Button

## 大厅“参与模式”切换按钮：显示当前角色，点击在「游戏 / 观战」之间切换。
##
## - 未进房：只改本地预选，不联网；
## - 已进房且处于 LOBBY：交给 LobbyService 广播；
## - 开局后：按钮禁用，角色锁定。

func _ready() -> void:
	# 本机多开测试：--mp-spectate 的实例默认以观战身份启动。
	if MpTest.has("--mp-spectate"):
		MPManager.set_local_spectator(true)
	pressed.connect(_on_pressed)
	MPManager.local_role_changed.connect(_on_role_changed)
	MPManager.phase_changed.connect(_on_phase_changed)
	MPManager.players_updated.connect(_refresh)
	_refresh()


func _on_pressed() -> void:
	var local: PlayerProfile = MPManager.get_local_player()
	MPManager.set_local_spectator(local == null or not local.is_spectator)


func _on_role_changed(_is_spectator: bool) -> void:
	_refresh()


func _on_phase_changed(_phase: int, _payload: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	var local: PlayerProfile = MPManager.get_local_player()
	var is_spectator: bool = local != null and local.is_spectator
	text = tr("观战") if is_spectator else tr("游戏")
	var online: bool = MPManager.net != null and MPManager.net.is_online()
	var locked: bool = online and (
		MPManager.phase != RoomPhase.Phase.LOBBY
		or (local != null and local.lobby_ready)
	)
	disabled = locked
