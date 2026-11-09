class_name HistoryGhostCache
extends RefCounted

@warning_ignore_start("unsafe_cast", "unsafe_call_argument", "unsafe_method_access", "unsafe_property_access")

## 联机游玩幽灵缓存。
##
## 每个历史记录关卡 user://mfmp_xxx.lvl 对应一个 user://ghosts/mfmp_xxx.ghost。
## 文件是 JSON（便于排查），采样字段与 MultiplayerAniSpriteManager 的
## send_ani_sprite_data 保持一致：
##   [t, x, y, suit, power, anim_index, frame, flip_h, scale_x, scale_y, rotation, dead]
##
## players[i].local == true 表示录制时的本地玩家；回放时跳过，不显示。

const DIR: String = "user://ghosts"
const VERSION: int = 1


## 关卡文件 -> 幽灵缓存文件。
static func ghost_path(level_path: String) -> String:
	if level_path.is_empty():
		return ""
	var base_name: String = level_path.get_file().get_basename()
	if base_name.is_empty():
		return ""
	return "%s/%s.ghost" % [DIR, base_name]


static func has_ghost(level_path: String) -> bool:
	var path: String = ghost_path(level_path)
	if path.is_empty():
		return false
	return FileAccess.file_exists(path)


static func save_ghost(level_path: String, duration: float, players: Array) -> bool:
	if players.is_empty():
		return false
	var path: String = ghost_path(level_path)
	if path.is_empty():
		return false
	_ensure_dir()
	var payload: Dictionary = {
		"version": VERSION,
		"level_file": level_path,
		"duration": snappedf(maxf(duration, 0.0), 0.01),
		"players": players,
	}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Log.e("HistoryGhostCache", ["无法写入幽灵缓存：", path])
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	Log.i("HistoryGhostCache", ["幽灵缓存已写入：", path])
	return true


## 读取失败/不存在时返回空字典，调用方不需要区分原因。
static func load_ghost(level_path: String) -> Dictionary:
	var path: String = ghost_path(level_path)
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	if text.is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		Log.w("HistoryGhostCache", ["幽灵缓存解析失败：", path])
		return {}
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return {}
	var dict: Dictionary = data
	if int(dict.get("version", 0)) != VERSION:
		return {}
	var players: Variant = dict.get("players", [])
	if not players is Array:
		return {}
	var result: Dictionary = {
		"duration": float(dict.get("duration", 0.0)),
		"players": players,
	}
	return result


static func _ensure_dir() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	if dir.dir_exists("ghosts"):
		return
	var error: Error = dir.make_dir("ghosts")
	if error != OK:
		Log.e("HistoryGhostCache", ["创建幽灵缓存目录失败：", error_string(error)])
