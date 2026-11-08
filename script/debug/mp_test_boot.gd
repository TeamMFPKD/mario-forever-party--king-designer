extends Node

## 本机多开联机测试启动器（autoload 名：MpTestBoot）。
##
## 三种用法：
## 1. 显式角色（tools/mp_test.ps1 使用）：--mp-role=host|join + --mp-name=...
## 2. 编辑器多实例（F5 / 自定义运行实例，不带参数）：自动按启动顺序命名为
##    test1 / test2 / test3；只有同时存在 2 个以上实例才生效，单个 F5 不受影响。
## 3. 显式槽位：--mp-slot=1|2|3 直接命名为 test1/2/3。
##
## 完整参数表见 script/debug/mp_test_flags.gd 文件头。

const HOST_PAGE: String = "GameRoomSize/HostPage"
const JOIN_PAGE: String = "GameRoomSize/JoinPage"
const CHOOSE_BOX: String = "GameRoomSize/ChooseModePanel/ChooseMode/HBoxContainer/VBoxContainer"
const PLAYER_BOX: String = "GameRoomSize/PlayerPage/UiPanel/UiMarginContainer/VBoxContainer"

## 编辑器多实例自动命名：用回环端口占位代替进程枚举。
## 端口绑定是原子的，进程退出/崩溃时由操作系统自动释放，不残留任何文件。
const SLOT_PORT_BASE: int = 39731
const SLOT_MAX: int = 3
## 等同批实例全部占位的最长时间，人齐就提前继续。
const SLOT_SETTLE_SECONDS: float = 2.5

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
var _slot_server: TCPServer = null
var _slot_index: int = 0

func _ready() -> void:
	_role = MpTest.get_value("--mp-role")
	if _role == "host" or _role == "join":
		_player_name = MpTest.get_value("--mp-name", "player")
		_host_ip = MpTest.get_value("--mp-ip", "127.0.0.1")
		_port = MpTest.get_value("--mp-port", "8914").to_int()
		Log.i("MPTEST", "boot role=%s name=%s port=%d" % [_role, _player_name, _port])
		_bootstrap()
		return

	var slot_value: String = MpTest.get_value("--mp-slot")
	if slot_value.is_valid_int():
		var slot_index: int = slot_value.to_int()
		if slot_index >= 1 and slot_index <= SLOT_MAX:
			_start_explicit_slot(slot_index)
			return

	# 显式给了名字就尊重它，不再自动编号
	if not MpTest.get_value("--mp-name").is_empty():
		return
	if _is_editor_launch():
		_start_editor_slots()

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

## 编辑器多实例：不带参数时的自动命名。
## 编辑器不会给实例编号，这里让实例抢 127.0.0.1 上的槽位端口，
## 抢到第几个端口就叫 test几；只有同时跑 2 个以上实例时才改名，
## 单个 F5 会释放端口、保持配置里的原名字。
func _start_editor_slots() -> void:
	var title: Node = await _wait_for_title()
	if title == null:
		return
	await get_tree().process_frame
	_apply_window(MpTest.get_value("--mp-win"))
	_apply_pad(MpTest.get_value("--mp-pad"))
	_override_edit_seconds(title)
	if not _claim_editor_slot():
		return
	var deadline: int = Time.get_ticks_msec() + int(SLOT_SETTLE_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if _used_slot_count() >= SLOT_MAX:
			break
		await get_tree().create_timer(0.1).timeout
	var used: int = _used_slot_count()
	if used < 2:
		Log.i("MPTEST", "editor slots=1, keep normal player name")
		_release_editor_slot()
		return
	_apply_player_name(title, "test%d" % _slot_index)
	Log.i("MPTEST", "editor slots=%d slot=%d" % [used, _slot_index])

## --mp-slot=N：跳过抢槽位，直接命名为 testN。
func _start_explicit_slot(slot_index: int) -> void:
	var title: Node = await _wait_for_title()
	if title == null:
		return
	await get_tree().process_frame
	_apply_window(MpTest.get_value("--mp-win"))
	_apply_pad(MpTest.get_value("--mp-pad"))
	_override_edit_seconds(title)
	_apply_player_name(title, "test%d" % slot_index)
	Log.i("MPTEST", "explicit slot=%d" % slot_index)

## 只有编辑器拉起的实例才满足这两个条件：
## 1. 运行的是编辑器构建（导出版为 false）；
## 2. 编辑器在启动前会设置 GODOT_EDITOR_CUSTOM_FEATURES（哪怕是空串），
##    命令行直接跑编辑器二进制不会设置它。
func _is_editor_launch() -> bool:
	if not OS.has_feature("editor"):
		return false
	return OS.has_environment("GODOT_EDITOR_CUSTOM_FEATURES")

## 依次尝试绑定槽位端口，抢到第几个就用第几个槽位。
func _claim_editor_slot() -> bool:
	for index: int in range(SLOT_MAX):
		var port: int = SLOT_PORT_BASE + index
		var server: TCPServer = TCPServer.new()
		if server.listen(port, "127.0.0.1") == OK:
			_slot_server = server
			_slot_index = index + 1
			Log.i("MPTEST", "editor slot=%d port=%d" % [_slot_index, port])
			return true
	return false

## 探测当前有几个槽位被占：能绑定就是空闲，绑不上就是被别的实例占着。
func _used_slot_count() -> int:
	var used: int = 0
	for index: int in range(SLOT_MAX):
		var server: TCPServer = TCPServer.new()
		if server.listen(SLOT_PORT_BASE + index, "127.0.0.1") == OK:
			server.stop()
		else:
			used += 1
	return used

func _release_editor_slot() -> void:
	if _slot_server != null:
		_slot_server.stop()
		_slot_server = null
	_slot_index = 0

## 把名字同时写进组织页和加入页的输入框，用户点哪个都带上 testN。
func _apply_player_name(title: Node, player_name: String) -> void:
	var host_edit: LineEdit = title.get_node_or_null(HOST_PAGE + "/MfpkdPanel/UiMarginContainer/VBoxContainer/UiLineEdit2") as LineEdit
	if host_edit != null:
		host_edit.text = player_name
	var join_edit: LineEdit = title.get_node_or_null(JOIN_PAGE + "/MfpkdPanel/UiMarginContainer/VBoxContainer/UiLineEdit3") as LineEdit
	if join_edit != null:
		join_edit.text = player_name
	MPManager.player_name = player_name
	if DisplayServer.get_name() != "headless":
		var base_title: String = str(ProjectSettings.get_setting("application/config/name", "MF: MP"))
		get_window().title = "%s [%s]" % [base_title, player_name]
	Log.i("MPTEST", "player name = %s" % player_name)

func _exit_tree() -> void:
	_release_editor_slot()

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
	# 注意：不能只看 get_connection_status()。OfflineMultiplayerPeer 的状态恒为 CONNECTED，
	# 必须确认当前 peer 已经是 ENet 且真的是 server。
	if _is_enet_connected() and multiplayer.is_server():
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
		if _is_enet_connected():
			Log.i("MPTEST", "joined id=%s name=%s" % [str(MPManager.player.id), _player_name])
			return true
		var peer: MultiplayerPeer = multiplayer.multiplayer_peer
		if peer == null or not (peer is ENetMultiplayerPeer) or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			Log.w("MPTEST", "connect retry %d/%d" % [index + 1, attempts])
			MPManager._on_join_button_pressed()
		await get_tree().create_timer(1.0).timeout
	Log.e("MPTEST", "join FAILED ip=%s port=%d" % [_host_ip, _port])
	return false

## OfflineMultiplayerPeer 的 connection_status 恒为 CONNECTED，必须限定 ENet。
func _is_enet_connected() -> bool:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if not (peer is ENetMultiplayerPeer):
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

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
		if _is_enet_connected() and not _find_local_player().is_empty():
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
