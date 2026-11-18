extends RefCounted

class_name AdventureShareCode

## 百人团存档的「快速导出 / 快速导入」文本码。
##
## 一条码 = 一个存档位（不是整份 adventure.ini），供玩家复制到剪贴板互相传递。
##
## 形如：
##   MFMP-RAID-2:<base64>
##     ^前缀   ^格式版本 ^压缩后的载荷
##
## 整条码是一次性给完的，不分段：点一次「快速导出」就把完整的一条放进剪贴板。
## 解码是"找到前缀、把后面连续的 base64 收下来"，而不是把整段文本当码——
## 所以中间夹着 QQ 的「昵称 时间」之类文字、或者聊天软件把长行折了行，都不影响识别。
##
## 载荷走的是一条很瘦的路子：
##   Dictionary（短键 + 关卡名只存一次、序列存下标 + 统计压成定长数组）
##   → var_to_bytes → DEFLATE → base64
## 对比最初的 ConfigFile 文本方案，同一个 514 格的无尽团从 22,208 字符降到 7,408。
## 指纹（fingerprint）刻意不传：接收方按自己本地的 .lvl 重新算，与「本地换了关卡」
## 走同一套作废逻辑，不占码长。

## 码前缀：看到它才知道这段文本里有没有我们的码。版本号跟在后面。
const PREFIX: String = "MFMP-RAID"
const FORMAT_VERSION: int = 2
const ERR_EMPTY: String = "码为空"
const ERR_PREFIX: String = "不是百人团存档码"
const ERR_BASE64: String = "码已损坏（base64 解不开）"
const ERR_UNPACK: String = "码已损坏（解压失败）"
const ERR_FORMAT: String = "码的格式版本不支持"
const ERR_PAYLOAD: String = "码里没有存档数据"
const ERR_LEVELS: String = "存档引用了本机没有的关卡：%s"

## 解压上限提示：一个团的载荷远小于这个数，给足余量即可。
## PackedByteArray.decompress() 只接受「原始大小的上限」，不是精确值。
const UNPACK_HINT: int = 4 * 1024 * 1024

## 统计行的固定列序号：压成数组后不带字段名。
const STAT_ATTEMPT: int = 0
const STAT_PASS: int = 1
const STAT_DEATH: int = 2
const STAT_SKIP: int = 3
const STAT_SKIP_SOFT: int = 4
const STAT_EXCLUDED: int = 5
const STAT_REASON: int = 6

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")


## 把某个存档位的团打成一条码。
## run 来自 AdventureStore.get_run(slot)；store 用来取这几关的单人统计。
static func encode(store: AdventureStore, slot: int, run: Dictionary) -> String:
	if run.is_empty():
		return ""
	return "%s-%d:%s" % [PREFIX, FORMAT_VERSION, _pack(_payload(store, slot, run))]


## 解一条码。成功返回 { ok, slot, run, levels }，失败返回 { ok = false, error }。
## 只解不写：要不要落盘由调用方决定（见 Adventure.import_share_code）。
static func decode(text: String) -> Dictionary:
	var found: Array[Dictionary] = _scan(text)
	if found.is_empty():
		return _fail(ERR_EMPTY if text.strip_edges().is_empty() else ERR_PREFIX)

	var body: String = str(found[0].get("body", ""))
	if not _is_base64(body):
		return _fail(ERR_BASE64)

	var packed: PackedByteArray = Marshalls.base64_to_raw(body)
	if packed.is_empty():
		return _fail(ERR_BASE64)
	var raw: PackedByteArray = packed.decompress(UNPACK_HINT, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return _fail(ERR_UNPACK)
	var payload: Variant = bytes_to_var(raw)
	if not payload is Dictionary:
		return _fail(ERR_PAYLOAD)
	return _restore(payload)


## 一条码引用到的关卡在本机有没有：缺关卡就没法续团，导入前先问清楚。
## 返回缺的关卡文件名（空数组 = 齐了）。
static func missing_levels(levels: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for key: String in levels.keys():
		if FileAccess.file_exists("user://" + key):
			continue
		if FileAccess.file_exists("user://liked courses/" + key):
			continue
		missing.append(key)
	return missing


## 界面在玩家还没点导入前用它做即时校验（只判断「看着像一条码」）。
static func looks_like_code(text: String) -> bool:
	return not _scan(text).is_empty()


# ---------------------------------------------------------------------------
# 扫描：从任意文本里把码挑出来
# ---------------------------------------------------------------------------

## 找出文本里所有码段。每项 = { index, total, body }。
##
## 不假设整段文本就是码：QQ 的聊天记录粘进来会带「昵称 时间」、空行、甚至别的消息。
## 所以这里逐字符扫，遇到前缀才开始收，遇到不像 base64 的字符就收尾。
static func _scan(text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cursor: int = 0
	while true:
		var start: int = text.find(PREFIX + "-", cursor)
		if start < 0:
			break
		var parsed: Dictionary = _scan_one(text, start)
		if parsed.is_empty():
			# 这段前缀后面跟的不是合法头，跳过它继续找下一个。
			cursor = start + PREFIX.length()
			continue
		result.append(parsed)
		cursor = int(parsed["end"])
	return result


## 从 start 处解析一条码。头写坏了就返回 {}（让调用处跳过这个前缀）。
static func _scan_one(text: String, start: int) -> Dictionary:
	var cursor: int = start + PREFIX.length() + 1
	# 版本号
	var version_start: int = cursor
	while cursor < text.length() and _is_digit(text.unicode_at(cursor)):
		cursor += 1
	if cursor == version_start:
		return {}
	if text.substr(version_start, cursor - version_start).to_int() != FORMAT_VERSION:
		return {}
	# 冒号后是 base64，一直收到第一个不是 base64 的字符为止
	if cursor >= text.length() or text.substr(cursor, 1) != ":":
		return {}
	cursor += 1
	var body: String = ""
	while cursor < text.length():
		var code: int = text.unicode_at(cursor)
		# 聊天软件会把长消息按宽度折行：空白要跳过继续收，不能在这里截断。
		if _is_space(code):
			cursor += 1
			continue
		# 尾部填充符 '=' 也要收：少一个字符，base64 就不再是 4 的倍数。
		if not _is_base64_char(code) and code != 61:
			break
		body += text.substr(cursor, 1)
		cursor += 1
	if body.is_empty():
		return {}
	return {
		"body": body,
		"end": cursor,
	}


# ---------------------------------------------------------------------------
# 载荷
# ---------------------------------------------------------------------------

## 打成一个很瘦的字典：短键 + 关卡名只存一份 + 序列存下标 + 统计压成定长数组。
static func _payload(store: AdventureStore, slot: int, run: Dictionary) -> Dictionary:
	var names: Array[String] = _level_names(run)
	var index_of: Dictionary = {}
	for position: int in range(names.size()):
		index_of[names[position]] = position
	var payload: Dictionary = {
		"id": str(run.get("id", "")),
		"m": str(run.get("mode", "finite")),
		"t": int(run.get("tier", 0)),
		"at": int(run.get("active_tier", 0)),
		"sd": int(run.get("seed", 0)),
		"i": int(run.get("index", 0)),
		"tl": int(run.get("total_levels", -1)),
		"lt": int(run.get("lives_total", 0)),
		"ll": int(run.get("lives_left", 0)),
		"lc": int(run.get("lives_cap", 0)),
		"cc": int(run.get("cleared_count", 0)),
		"d": int(run.get("deaths", 0)),
		"sc": int(run.get("skipped_count", 0)),
		"ss": int(run.get("skipped_soft", 0)),
		"sh": int(run.get("skipped_hard", 0)),
		"cy": int(run.get("cycle", 1)),
		"st": int(run.get("started_at", 0)),
		"slot": slot,
		"names": names,
		"keys": _indices(run.get("level_keys", []), index_of),
		"played": _indices(run.get("cycle_played", []), index_of),
		"skipped": _indices(run.get("skipped_keys", []), index_of),
		"stats": _stats_table(store, names),
	}
	return payload


## 从载荷还原成调用方要的结构：run 用存档里的长键名，levels 用关卡名做键。
static func _restore(payload: Dictionary) -> Dictionary:
	var names: Array = payload.get("names", [])
	var keys: Array = payload.get("keys", [])
	var level_keys: Array = []
	for value: Variant in keys:
		var position: int = int(value)
		if position >= 0 and position < names.size():
			level_keys.append(str(names[position]))
	var stats: Array = payload.get("stats", [])
	var levels: Dictionary = {}
	for position: int in range(names.size()):
		var name: String = str(names[position])
		var row: Array = stats[position] if position < stats.size() and stats[position] is Array else []
		if row.is_empty():
			continue
		levels[name] = {
			"file": name,
			"solo_attempt": _row_int(row, STAT_ATTEMPT),
			"solo_pass": _row_int(row, STAT_PASS),
			"solo_death": _row_int(row, STAT_DEATH),
			"solo_skip": _row_int(row, STAT_SKIP),
			"solo_skip_soft": _row_int(row, STAT_SKIP_SOFT),
			"excluded": _row_bool(row, STAT_EXCLUDED),
			"exclude_reason": _row_str(row, STAT_REASON),
		}
	var run: Dictionary = {
		"id": str(payload.get("id", "")),
		"mode": str(payload.get("m", "finite")),
		"tier": _num(payload, "t"),
		"active_tier": _num(payload, "at"),
		"seed": _num(payload, "sd"),
		"index": _num(payload, "i"),
		"total_levels": _num(payload, "tl"),
		"lives_total": _num(payload, "lt"),
		"lives_left": _num(payload, "ll"),
		"lives_cap": _num(payload, "lc"),
		"cleared_count": _num(payload, "cc"),
		"deaths": _num(payload, "d"),
		"skipped_count": _num(payload, "sc"),
		"skipped_soft": _num(payload, "ss"),
		"skipped_hard": _num(payload, "sh"),
		"cycle": _num(payload, "cy"),
		"started_at": _num(payload, "st"),
		"level_keys": level_keys,
		"cycle_played": _restore_names(payload.get("played", []), names),
		"skipped_keys": _restore_names(payload.get("skipped", []), names),
	}
	if not level_keys.is_empty():
		return {
			"ok": true,
			"error": "",
			"slot": _num(payload, "slot"),
			"run": run,
			"levels": levels,
		}
	return _fail(ERR_PAYLOAD)


static func _restore_names(values: Variant, names: Array) -> Array:
	var result: Array = []
	if not values is Array:
		return result
	for value: Variant in values:
		var position: int = int(value)
		if position >= 0 and position < names.size():
			result.append(str(names[position]))
	return result


static func _num(payload: Dictionary, key: String) -> int:
	var value: Variant = payload.get(key, 0)
	if value is int or value is float or value is bool:
		return int(value)
	return 0


static func _row_int(row: Array, column: int) -> int:
	if column >= row.size():
		return 0
	var value: Variant = row[column]
	if value is int or value is float or value is bool:
		return int(value)
	return 0


static func _row_bool(row: Array, column: int) -> bool:
	return _row_int(row, column) != 0


static func _row_str(row: Array, column: int) -> String:
	if column >= row.size():
		return ""
	return str(row[column])


## 这个团用到的关卡名（去重 + 排序：排序后相邻名字前缀高度相似，压缩率更好）。
static func _level_names(run: Dictionary) -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for entry: Variant in run.get("level_keys", []):
		var key: String = str(entry)
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		result.append(key)
	result.sort()
	return result


## 关卡名序列 → 下标序列。认不出来的名字记 -1（不会静默丢格子）。
static func _indices(values: Variant, index_of: Dictionary) -> Array:
	var result: Array = []
	if not values is Array:
		return result
	for value: Variant in values:
		result.append(int(index_of.get(str(value), -1)))
	return result


## 每关的统计压成定长数组，顺序与 names 一致，不重复写字段名。
static func _stats_table(store: AdventureStore, names: Array[String]) -> Array:
	var table: Array = []
	if store == null:
		return table
	for name: String in names:
		var section: String = store.level_section(name)
		if not store.config.has_section(section):
			table.append([])
			continue
		table.append([
			int(store.config.get_value(section, "solo_attempt", 0)),
			int(store.config.get_value(section, "solo_pass", 0)),
			int(store.config.get_value(section, "solo_death", 0)),
			int(store.config.get_value(section, "solo_skip", 0)),
			int(store.config.get_value(section, "solo_skip_soft", 0)),
			1 if bool(store.config.get_value(section, "excluded", false)) else 0,
			str(store.config.get_value(section, "exclude_reason", "")),
		])
	return table


static func _pack(payload: Dictionary) -> String:
	var raw: PackedByteArray = var_to_bytes(payload)
	var packed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_DEFLATE)
	return Marshalls.raw_to_base64(packed)


# ---------------------------------------------------------------------------
# 小工具
# ---------------------------------------------------------------------------

## 先自己校验一遍 base64：直接丢给 Marshalls 会在引擎里打一条 ERROR，
## 而玩家粘错东西是常规操作，不该每错一次就脏一次日志。
## 注意：分段后的单段不保证是 4 的倍数，填充符也可能落在一段的中后部，
## 所以这里只校验「字符集对、填充只在尾部」这一层的宽松版，
## 真正的合法性交给后面的 Marshalls.base64_to_raw —— 它在别处已经先被拦过一次。
static func _is_base64(text: String) -> bool:
	if text.is_empty() or text.length() % 4 != 0:
		return false
	return _is_base64_lax(text)


## 不要求 4 的倍数：给分段码用（每段单独看可能缺尾部填充）。
static func _is_base64_lax(text: String) -> bool:
	if text.is_empty():
		return false
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		if code == 61:
			continue
		if not _is_base64_char(code):
			return false
	return true


static func _is_base64_char(code: int) -> bool:
	var is_upper: bool = code >= 65 and code <= 90
	var is_lower: bool = code >= 97 and code <= 122
	var is_digit: bool = code >= 48 and code <= 57
	# '+' 与 '/' 是标准字符；'-' 与 '_' 是 URL-safe 变体，一并放行。
	return is_upper or is_lower or is_digit or code == 43 or code == 47 or code == 45 or code == 95


static func _is_digit(code: int) -> bool:
	return code >= 48 and code <= 57


static func _is_space(code: int) -> bool:
	return code == 32 or code == 9 or code == 10 or code == 13


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "slot": 0, "run": {}, "levels": {}}
