class_name AdventureLevelIdentity
extends RefCounted

## 关卡身份：文件名当 key，布局内容哈希当前 16 位指纹。
## 指纹刻意排除 version / time_used / pass_count / death_count：
## - version、time_used 是编辑器元数据；
## - pass_count、death_count 会被联机结算改写。
## 这样同一份布局在联机写完统计后，指纹不会变。

const FINGERPRINT_FIELDS: Array[String] = [
	"level_size",
	"level_theme",
	"tilemap_data",
	"object_data",
	"pipe_line_data",
	"lives",
]


static func key_from_path(path: String) -> String:
	return path.get_file()


static func fingerprint_from_json_text(text: String) -> String:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return ""
	var data: Variant = json.data
	if not data is Dictionary:
		return ""
	var source: Dictionary = data
	var canonical: Dictionary = {}
	for field: String in FINGERPRINT_FIELDS:
		if source.has(field):
			canonical[field] = _canonicalize(source[field])
	var canonical_text: String = JSON.stringify(canonical, "")
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical_text.to_utf8_buffer())
	return context.finish().hex_encode().substr(0, 16)


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var keys: Array = source.keys()
		keys.sort()
		var result: Dictionary = {}
		for key: Variant in keys:
			result[str(key)] = _canonicalize(source[key])
		return result
	if value is Array:
		var source: Array = value
		var result: Array = []
		for entry: Variant in source:
			result.append(_canonicalize(entry))
		return result
	return value
