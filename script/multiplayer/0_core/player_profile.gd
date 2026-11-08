class_name PlayerProfile
extends RefCounted

# 网络字典的值都是 Variant，集中在这里显式转换；本项目把 unsafe_* 警告当成错误。
@warning_ignore_start("unsafe_call_argument")

## 房间内一名玩家的完整本地状态。
##
## 只在本进程内使用，不直接参与 RPC。网络传输一律走 [method to_wire] /
## [method apply_wire] 生成的 Dictionary，避免自定义类型在序列化上的不确定性。
##
## 字段分组与同步粒度对应：
## - identity：id / name / avatar_id / device_id / is_host
## - lobby：大厅准备
## - edit：编辑房间“制作完毕”
## - transfer：关卡文件接收状态
## - match：对局与结算
##
## 注意：关卡 JSON 正文不再放在这里，只在 LevelTransferService 内部短暂存在，
## 校验通过后落盘，内存只保留 level_file_name。

const GROUP_IDENTITY: StringName = &"identity"
const GROUP_LOBBY: StringName = &"lobby"
const GROUP_EDIT: StringName = &"edit"
const GROUP_TRANSFER: StringName = &"transfer"
const GROUP_MATCH: StringName = &"match"
const GROUP_ALL: StringName = &"all"

const NAME_LIMIT: int = 12

var id: int = 0
var name: String = ""
var avatar_id: String = ""
var device_id: String = ""
var is_host: bool = false

var lobby_ready: bool = false
var edit_finished: bool = false

var has_level: bool = false
var level_file_name: String = ""
var level_ok: bool = false

var reach_end: bool = false
var cause_pass: int = 0
var cause_death: int = 0
var pass_count: int = 0
var score: int = 0
var clear_rate: float = 0.0


func to_wire(group: StringName = GROUP_ALL) -> Dictionary:
	var data: Dictionary = {}
	if group == GROUP_ALL or group == GROUP_IDENTITY:
		data["id"] = id
		data["name"] = name
		data["avatar_id"] = avatar_id
		data["device_id"] = device_id
		data["is_host"] = is_host
	if group == GROUP_ALL or group == GROUP_LOBBY:
		data["lobby_ready"] = lobby_ready
	if group == GROUP_ALL or group == GROUP_EDIT:
		data["edit_finished"] = edit_finished
	if group == GROUP_ALL or group == GROUP_TRANSFER:
		data["has_level"] = has_level
		data["level_file_name"] = level_file_name
		data["level_ok"] = level_ok
	if group == GROUP_ALL or group == GROUP_MATCH:
		data["reach_end"] = reach_end
		data["cause_pass"] = cause_pass
		data["cause_death"] = cause_death
		data["pass_count"] = pass_count
		data["score"] = score
		data["clear_rate"] = clear_rate
	return data


func apply_wire(data: Dictionary) -> void:
	if data.has("id"):
		id = int(data["id"])
	if data.has("name"):
		name = str(data["name"]).substr(0, NAME_LIMIT)
	if data.has("avatar_id"):
		avatar_id = str(data["avatar_id"])
	if data.has("device_id"):
		device_id = str(data["device_id"])
	if data.has("is_host"):
		is_host = bool(data["is_host"])
	if data.has("lobby_ready"):
		lobby_ready = bool(data["lobby_ready"])
	if data.has("edit_finished"):
		edit_finished = bool(data["edit_finished"])
	if data.has("has_level"):
		has_level = bool(data["has_level"])
	if data.has("level_file_name"):
		level_file_name = str(data["level_file_name"])
	if data.has("level_ok"):
		level_ok = bool(data["level_ok"])
	if data.has("reach_end"):
		reach_end = bool(data["reach_end"])
	if data.has("cause_pass"):
		cause_pass = int(data["cause_pass"])
	if data.has("cause_death"):
		cause_death = int(data["cause_death"])
	if data.has("pass_count"):
		pass_count = int(data["pass_count"])
	if data.has("score"):
		score = int(data["score"])
	if data.has("clear_rate"):
		clear_rate = float(data["clear_rate"])


static func from_wire(data: Dictionary) -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.apply_wire(data)
	return profile


## 返回一份可以直接放进 JSON / 结算界面的轻量字典。
func to_result_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"cause_pass": cause_pass,
		"cause_death": cause_death,
		"pass_count": pass_count,
		"clear_rate": clear_rate,
		"score": score,
	}


## 回到大厅时清空“本局”数据，保留身份与房间状态。
func reset_match_state() -> void:
	edit_finished = false
	has_level = false
	level_file_name = ""
	level_ok = false
	reach_end = false
	cause_pass = 0
	cause_death = 0
	pass_count = 0
	score = 0
	clear_rate = 0.0


func device_tag() -> String:
	if device_id.is_empty():
		return "?????"
	var tag: String = device_id.replace("{", "").replace("}", "").replace("-", "")
	return tag.substr(0, 5)
