extends Node

## 让 [LineEdit] / [TextEdit] 的 Godot 内置右键菜单（撤销 / 复制 / 粘贴…）跟随控件字号，
## 并让条目文字走本工程的 .po 翻译（i18n/mfmp_translation.*.po）。
##
## Godot 内置菜单是一个 [PopupMenu]：字号取主题默认的 16px，条目文字是引擎自己 ETR() 的英文，
## 两者都不受本作 UI 与翻译影响（本作 UI 在 1920×1080 画布上普遍是 24～32px 字号）。
## [method apply] 会做三件事：
## - 按控件自身字号等比放大菜单的字号与间距；
## - 把条目文字换成简中原文，再经 [TranslationServer] 输出当前语言；
## - 语言可在运行中切换（见 script/option/language_button.gd），所以每次弹出前都会重新取一次译文。
##
## 用法：输入框进入场景树时调用一次即可（见 ui_line_edit_input_blocker.gd）：
## [codeblock]
## TextContextMenu.apply(self)
## [/codeblock]

class_name TextContextMenu

## Godot 默认主题里 PopupMenu 的字号，作为字号→间距的等比换算基准。
const BASE_FONT_SIZE: int = 16
const BASE_INDENT: int = 10
const BASE_SEPARATION: int = 4
const BASE_ITEM_PADDING: int = 2

## 内置菜单条目 id → 简中原文（即 .po 的 msgid）。
## 控制字符子菜单（LRM / RLM…）是 Unicode 术语缩写，保持引擎原文，不在此表里。
const MENU_TEXT_KEYS: Dictionary = {
	LineEdit.MENU_CUT: "剪切",
	LineEdit.MENU_COPY: "复制",
	LineEdit.MENU_PASTE: "粘贴",
	LineEdit.MENU_SELECT_ALL: "全选",
	LineEdit.MENU_CLEAR: "清除",
	LineEdit.MENU_UNDO: "撤销",
	LineEdit.MENU_REDO: "重做",
	LineEdit.MENU_SUBMENU_TEXT_DIR: "文本书写方向",
	LineEdit.MENU_DIR_INHERITED: "跟随布局方向",
	LineEdit.MENU_DIR_AUTO: "自动检测方向",
	LineEdit.MENU_DIR_LTR: "从左到右",
	LineEdit.MENU_DIR_RTL: "从右到左",
	LineEdit.MENU_DISPLAY_UCC: "显示控制字符",
	LineEdit.MENU_SUBMENU_INSERT_UCC: "插入控制字符",
	LineEdit.MENU_EMOJI_AND_SYMBOL: "表情与符号",
}

## 标记菜单已挂过“弹出前刷新译文”，避免重复连接信号。
const LOCALE_HOOK_META: StringName = &"text_context_menu_locale_hook"

## 让 [param text_control] 内置右键菜单的字号跟随它自己的字号，并把条目文字本地化。
static func apply(text_control: Control) -> void:
	var font_size: int = text_control.get_theme_font_size("font_size")
	if font_size <= 0:
		return
	var menu: PopupMenu = _get_builtin_menu(text_control)
	if menu == null:
		return
	_scale_menu(menu, font_size)
	_localize_menu(menu)
	_hook_locale_refresh(menu)

## 取控件内置的右键菜单（首次调用时 Godot 才真正创建它）。
static func _get_builtin_menu(text_control: Control) -> PopupMenu:
	if text_control is LineEdit:
		return (text_control as LineEdit).get_menu()
	if text_control is TextEdit:
		return (text_control as TextEdit).get_menu()
	return null

static func _scale_menu(menu: PopupMenu, font_size: int) -> void:
	var ratio: float = float(font_size) / float(BASE_FONT_SIZE)
	menu.add_theme_font_size_override("font_size", font_size)
	menu.add_theme_constant_override("indent", _scale_constant(BASE_INDENT, ratio))
	menu.add_theme_constant_override("h_separation", _scale_constant(BASE_SEPARATION, ratio))
	menu.add_theme_constant_override("v_separation", _scale_constant(BASE_SEPARATION, ratio))
	menu.add_theme_constant_override("item_start_padding", _scale_constant(BASE_ITEM_PADDING, ratio))
	menu.add_theme_constant_override("item_end_padding", _scale_constant(BASE_ITEM_PADDING, ratio))
	# 子菜单（如“插入控制字符”）是独立的 PopupMenu，一并放大
	for index: int in range(menu.item_count):
		var submenu: PopupMenu = menu.get_item_submenu_node(index)
		if submenu != null:
			_scale_menu(submenu, font_size)

static func _scale_constant(base_value: int, ratio: float) -> int:
	return maxi(base_value, roundi(float(base_value) * ratio))

static func _localize_menu(menu: PopupMenu) -> void:
	for index: int in range(menu.item_count):
		var item_id: int = menu.get_item_id(index)
		if MENU_TEXT_KEYS.has(item_id):
			var key: String = str(MENU_TEXT_KEYS[item_id])
			menu.set_item_text(index, TranslationServer.translate(key))
		var submenu: PopupMenu = menu.get_item_submenu_node(index)
		if submenu != null:
			_localize_menu(submenu)

static func _hook_locale_refresh(menu: PopupMenu) -> void:
	if menu.has_meta(LOCALE_HOOK_META):
		return
	menu.set_meta(LOCALE_HOOK_META, true)
	menu.about_to_popup.connect(_on_menu_about_to_popup.bind(menu))

static func _on_menu_about_to_popup(menu: PopupMenu) -> void:
	_localize_menu(menu)
