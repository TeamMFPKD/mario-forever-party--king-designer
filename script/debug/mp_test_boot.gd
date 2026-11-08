extends Node

## 本机多开联机测试启动器（autoload 名：MpTestBoot）。
##
## 不传 --mp-role 时立即返回，对正常启动零影响。
## 传了之后按参数自动完成「组织 / 加入 → 准备完毕 → 开始」，
## 供 tools/mp_test.ps1 做三实例联调（人类测试与自动测试共用同一套参数）。
##
## 完整参数表见 script/debug/mp_test_flags.gd 文件头。

const HOST_PAGE: String = "GameRoomSize/HostPage"
const JOIN_PAGE: String = "GameRoomSize/JoinPage"
const CHOOSE_BOX: String = "GameRoomSize/ChooseModePanel/ChooseMode/HBoxContainer/VBoxContainer"
const PLAYER_BOX: String = "GameRoomSize/PlayerPage/UiPanel/UiMarginContainer/VBoxContainer"

## 输入动作：--mp-pad 过滤手柄时只处理这些动作。
var _pad_actions: PackedStringArray = PackedStringArray([
	"move_up",
	"move_down",
	"move_left",
	"move_right",
	"move_fire",
	"move_jump",
	"restart",
	"photo",
])

var _role: String = ""
var _player_name: String = "player"
var _host_ip: String = "127.0.0.1"
var _port: int = 8914

func _ready() -> void:
	_role = MpTest.get_value("--mp-role")
	if _role != "host" and _role != "join":
		return
	_player_name = MpTest.get_value("--mp-name", "player")
	_host_ip = MpTest.get_value("--mp-ip", "127.0.0.1")
	_port = MpTest.get_value("--mp-port", "8914").to_int()
	Log.i("MPTEST", "boot role=%s name=%s port=%d" % [_role, _player_name, _port])
	_bootstrap()

func _bootstrap() -> void:
	var title: Node = await _wait_for_title()
	if title == null:
		return
	# 让 resolution_button 等 _ready 里的窗口操作先跑完，再覆盖窗口尺寸
	await get_tree().process_frame
	_apply_window(MpTest.get_value("--mp-win"))
	_apply_pad(MpTest.get_value("--mp-pad"))
	_override_edit_seconds(title)

	var ok: bool = false
	if _role == "host":
		ok = await _do_host(title)
	else:
		ok = await _do_join(title)
	if not ok:
		return

	_watch_auto_exit()
	if MpTest.has("--mp-auto-ready"):
		_auto_ready_loop(title)
	if _role == "host" and MpTest.has("--mp-auto-start"):
		_auto_start(title)

## 等主场景 title.tscn 的根节点（名为 Title）完全就绪。
func _wait_for_title() -> Node:
	while true:
		var title: Node = get_tree().root.get_node_or_null("Title")
		if title != null and title.is_node_ready():
			return title
		await get_tree().process_frame
	return null

## 应用 --mp-win=<宽>x<高>+<x>+<y>，无头模式忽略。
func _apply_window(spec: String) -> void:
	if spec.is_empty() or DisplayServer.get_name() == "headless":
		return
	var parts: PackedStringArray = spec.split("+")
	var wh: PackedStringArray = parts[0].split("x")
	if wh.size() < 2:
		Log.w("MPTEST", "bad --mp-win=%s" % spec)
		return
	var width: int = maxi(320, wh[0].to_int())
	var height: int = maxi(180, wh[1].to_int())
	var window: Window = get_window()
	window.size = Vector2i(width, height)
	if parts.size() >= 3:
		window.position = Vector2i(parts[1].to_int(), parts[2].to_int())
	Log.i("MPTEST", "window %dx%d pos=%s" % [width, height, spec])

## 只接受指定手柄设备号。同机多开时三个实例会收到同一批手柄事件，
## 必须按 device 过滤，否则三份实例会一起动。
func _apply_pad(value: String) -> void:
	if not value.is_valid_int():
		return
	var device: int = value.to_int()
	for action: String in _pad_actions:
		if not InputMap.has_action(action):
			continue
		var kept: Array[InputEvent] = []
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		for event: InputEvent in events:
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				var copy: InputEvent = event.duplicate() as InputEvent
				copy.device = device
				kept.append(copy)
			else:
				kept.append(event)
		InputMap.action_erase_events(action)
		for event: InputEvent in kept:
			InputMap.action_add_event(action, event)
	Log.i("MPTEST", "gamepad filter device=%d" % device)

## 覆盖大厅里的“编辑时限”滑条（10~300 秒，步长 10）。
func _override_edit_seconds(title: Node) -> void:
	var raw: String = MpTest.get_value("--mp-edit-seconds")
	if not raw.is_valid_int():
		return
	var bar: HScrollBar = title.get_node_or_null(PLAYER_BOX + "/HScrollBar") as HScrollBar
	if bar == null:
		Log.w("MPTEST", "HScrollBar not found")
		return
	bar.value = clampi(raw.to_int(), int(bar.min_value), int(bar.max_value))
	Log.i("MPTEST", "edit seconds = %d" % int(bar.value))

## 走真实按钮：按钮的 _ready/tscn 连线里还有隐藏页面、显示 PlayerPage 等副作用。
func _do_host(title: Node) -> bool:
	var page: Control = title.get_node_or_null(HOST_PAGE) as Control
	if page == null:
		Log.e("MPTEST", "HostPage not found")
		return false
	var box: Node = page.get_node("MfpkdPanel/UiMarginContainer/VBoxContainer")
	(box.get_node("UiLineEdit") as LineEdit).text = str(_port)
	(box.get_node("UiLineEdit2") as LineEdit).text = _player_name
	var choose: Button = title.get_node_or_null(CHOOSE_BOX + "/ChooseHostButton") as Button
	var host_button: Button = box.get_node_or_null("HBoxContainer/HostButton") as Button
	if choose == null or host_button == null:
		Log.e("MPTEST", "host buttons not found")
		return false
	choose.emit_signal("pressed")
	host_button.emit_signal("pressed")

	await get_tree().process_frame
	await get_tree().process_frame
	if _peer_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		Log.i("MPTEST", "host listening port=%d name=%s" % [_port, _player_name])
		return true
	Log.e("MPTEST", "host listen FAILED port=%d (port already in use?)" % _port)
	return false

func _do_join(title: Node) -> bool:
	var page: Control = title.get_node_or_null(JOIN_PAGE) as Control
	if page == null:
		Log.e("MPTEST", "JoinPage not found")
		return false
	var box: Node = page.get_node("MfpkdPanel/UiMarginContainer/VBoxContainer")
	(box.get_node("UiLineEdit") as LineEdit).text = _host_ip
	(box.get_node("UiLineEdit2") as LineEdit).text = str(_port)
	(box.get_node("UiLineEdit3") as LineEdit).text = _player_name
	var choose: Button = title.get_node_or_null(CHOOSE_BOX + "/ChooseJoinButton") as Button
	var join_button: Button = box.get_node_or_null("HBoxContainer/JoinButton") as Button
	if choose == null or join_button == null:
		Log.e("MPTEST", "join buttons not found")
		return false
	choose.emit_signal("pressed")
	join_button.emit_signal("pressed")

	# 主机可能比客户端晚起好，连接失败就重试；重试直接调 MPManager，
	# 不再走按钮，避免反复写 user://game_settings.cfg。
	var attempts: int = maxi(1, MpTest.get_value("--mp-join-retries", "40").to_int())
	for index: int in attempts:
		var status: MultiplayerPeer.ConnectionStatus = _peer_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			Log.i("MPTEST", "joined id=%s name=%s" % [str(MPManager.player.id), _player_name])
			return true
		if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			Log.w("MPTEST", "connect retry %d/%d" % [index + 1, attempts])
			MPManager._on_join_button_pressed()
		await get_tree().create_timer(1.0).timeout
	Log.e("MPTEST", "join FAILED ip=%s port=%d" % [_host_ip, _port])
	return false

func _peer_status() -> MultiplayerPeer.ConnectionStatus:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return MultiplayerPeer.CONNECTION_DISCONNECTED
	return peer.get_connection_status()

func _find_local_player() -> Dictionary:
	var local_id: Variant = MPManager.player.id
	for entry: Dictionary in MPManager.players:
		var entry_id: Variant = entry.get("id")
		if entry_id == local_id:
			return entry
	return {}

func _is_local_ready() -> bool:
	var data: Dictionary = _find_local_player()
	if data.is_empty():
		return false
	var is_ready: bool = data.get("is_ready_to_start", false)
	return is_ready

## 自动准备：连接成功后立刻点一次“准备完毕”，之后每 3 秒补一次。
## 补发是为了顶掉 ready_button 的失焦/无输入自动取消（未加 --mp-no-ready-timeout 时）。
func _auto_ready_loop(title: Node) -> void:
	var ready_button: Button = title.get_node_or_null(PLAYER_BOX + "/HBoxContainer/ReadyButton") as Button
	if ready_button == null:
		Log.e("MPTEST", "ReadyButton not found")
		return
	while is_instance_valid(title) and is_instance_valid(ready_button):
		if _peer_status() == MultiplayerPeer.CONNECTION_CONNECTED and not _find_local_player().is_empty():
			if not _is_local_ready():
				ready_button.emit_signal("pressed")
				Log.i("MPTEST", "ready sent name=%s" % _player_name)
		await get_tree().create_timer(3.0).timeout

## 主机自动开局：等满 --mp-expect 人且全部准备后点“开始”。
func _auto_start(title: Node) -> void:
	var start_button: Button = title.get_node_or_null(PLAYER_BOX + "/HBoxContainer/StartButton") as Button
	if start_button == null:
		Log.e("MPTEST", "StartButton not found")
		return
	var expect: int = maxi(2, MpTest.get_value("--mp-expect", "3").to_int())
	var deadline: int = Time.get_ticks_msec() + 120000
	while is_instance_valid(title) and Time.get_ticks_msec() < deadline:
		if MPManager.is_in_game:
			return
		var players: Array = MPManager.players
		if players.size() >= expect and _all_ready(players):
			start_button.emit_signal("pressed")
			Log.i("MPTEST", "all players ready (%d), start pressed" % players.size())
			return
		await get_tree().create_timer(0.5).timeout
	Log.e("MPTEST", "auto start TIMEOUT")

func _all_ready(players: Array) -> bool:
	for entry: Dictionary in players:
		var is_ready: bool = entry.get("is_ready_to_start", false)
		if not is_ready:
			return false
	return true

## 自动测试收尾：房间开局后等场景切换完成再退出，让 --log-file 完整落盘。
func _watch_auto_exit() -> void:
	if not MpTest.has("--mp-auto-exit"):
		return
	var deadline: int = Time.get_ticks_msec() + 180000
	while not MPManager.is_in_game and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.5).timeout
	if not MPManager.is_in_game:
		Log.e("MPTEST", "auto exit: game never started")
		return
	Log.i("MPTEST", "game started, auto exit in 8s")
	await get_tree().create_timer(8.0).timeout
	Log.i("MPTEST", "quit after game_start")
	get_tree().quit()
