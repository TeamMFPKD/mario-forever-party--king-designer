class_name QuickMessageTable
extends RefCounted

## 预置快捷用语表（共 21 组）。
## 文本存放在 res://i18n/mfmp_translation.<locale>.po，key 为 MSG_QUICK_01 … MSG_QUICK_21，
## 联机时只同步序号，各端用当前语言显示（见 message_creator.gd）。

const COUNT: int = 21
const KEY_PREFIX: String = "MSG_QUICK_"


static func key_of(quick_id: int) -> String:
	return "%s%02d" % [KEY_PREFIX, quick_id]


static func text_of(quick_id: int) -> String:
	if not is_valid_id(quick_id):
		return ""
	return String(TranslationServer.translate(StringName(key_of(quick_id))))


static func is_valid_id(quick_id: int) -> bool:
	return quick_id >= 1 and quick_id <= COUNT
