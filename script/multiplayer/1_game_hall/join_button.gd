extends Button

@export var line_edit_frp_domain: LineEdit
@export var line_edit_remote_port: LineEdit
@export var line_edit_player_name: LineEdit

@export var player_page: Control

@export var player_name_limit: int = 12

const GameConfigType: GDScript = preload("res://script/utils/game_config.gd")
const ROLE_TOGGLE_SCRIPT: GDScript = preload("res://script/multiplayer/1_game_hall/role_toggle_button.gd")

var game_config: GameConfigType
var frp_domain: String = ""
var remote_port: int = 0
var player_name: String = ""


func _ready() -> void:
	pressed.connect(_on_button_pressed)
	game_config = GameConfig

	# 从配置加载默认值
	if game_config:
		line_edit_frp_domain.text = game_config.get_frp_domain()
		line_edit_remote_port.text = str(game_config.get_remote_port())
		line_edit_player_name.text = game_config.get_player_name()
	_add_role_row()


func _add_role_row() -> void:
	var hbox: Node = get_parent()
	if hbox == null:
		return
	var box: Node = hbox.get_parent()
	if box == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "RoleRow"
	row.theme = preload("res://mfmp_theme.tres")
	# 与下方 Quit/Host 那行保持同样的间距，左右两格才能宽度对齐。
	row.add_theme_constant_override("separation", 32)
	# 文案与字号对齐 UiLabel（45 / outline 7），并撑满左半格。
	var label: Label = Label.new()
	label.text = tr("参与模式")
	label.add_theme_font_size_override("font_size", 45)
	label.add_theme_constant_override("outline_size", 7)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	# 与玩家列表里的角色徽章同一套外观（圆角矩形 + 白字描边），尺寸放大一号。
	var button: Button = Button.new()
	button.name = "RoleToggleButton"
	button.set_script(ROLE_TOGGLE_SCRIPT)
	@warning_ignore("unsafe_method_access")
	ROLE_TOGGLE_SCRIPT.apply_badge_style(button)
	row.add_child(button)
	box.add_child.call_deferred(row)
	# 放在头像选择器之后、底部按钮行之前。
	box.move_child.call_deferred(row, hbox.get_index())


func _on_button_pressed() -> void:
	frp_domain = line_edit_frp_domain.text.strip_edges()
	remote_port = line_edit_remote_port.text.to_int()
	player_name = line_edit_player_name.text.substr(0, player_name_limit)

	var manager: MultiplayerManager = MPManager
	manager.frp_domain = frp_domain
	manager.remote_port = remote_port
	manager.player_name = player_name
	manager.player.name = player_name
	# 测试启动的观看身份由 role_toggle_button 在 _ready 里预选；
	# 正常界面由“参与模式”按钮决定，这里不覆盖。
	if MpTest.has("--mp-spectate"):
		manager.player.is_spectator = true

	# 测试启动不写全局配置，避免同机多实例并发覆盖 user://game_settings.cfg。
	if game_config and not MpTest.is_test_launch():
		game_config.set_frp_domain(frp_domain)
		game_config.set_remote_port(remote_port)
		game_config.set_player_name(player_name)

	manager.join_game(frp_domain, remote_port)
