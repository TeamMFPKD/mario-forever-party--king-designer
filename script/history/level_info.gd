extends MarginContainer

@export var date_label : Label
@export var author_label : Label
@export var clear_rate_label : Label

var level_file_path : String = ""
var level_path_set : Node

func _ready():
	# 等待一帧确保所有节点都已准备好
	await get_tree().process_frame
	level_path_set = get_tree().get_first_node_in_group("level_path_set")
	level_file_path = level_path_set.get_meta("level_path_name")
	_update_level_info()

# 解析关卡文件名并更新Label
func _update_level_info() -> void:
	if level_file_path.is_empty():
		return
	
	# 解析文件名格式: mfmp_YYYY-MM-DD_HH-MM-SS_作者名_随机ID.lvl
	var file_parts = level_file_path.replace(".lvl", "").split("_")
	
	# 提取日期信息
	if file_parts.size() >= 2:
		var date_str = file_parts[1]  # YYYY-MM-DD
		var time_str = ""
		if file_parts.size() >= 3:
			time_str = file_parts[2]  # HH-MM-SS
			# 将时间格式转换为更易读的格式
			time_str = time_str.replace("-", ":")
		
		var display_date = date_str
		if not time_str.is_empty():
			display_date += " " + time_str
		
		if date_label:
			date_label.text = display_date
	
	# 提取作者信息
	if file_parts.size() >= 4:
		var author = file_parts[3]
		if author_label:
			author_label.text = author
	
	# 计算通过率
	_calculate_clear_rate()

# 计算关卡通过率
func _calculate_clear_rate() -> void:
	if level_file_path.is_empty() or not clear_rate_label:
		return
	
	var level_data = _load_level_data()
	if level_data.is_empty():
		clear_rate_label.text = "数据缺失"
		return
	
	# 解析关卡数据中的统计信息
	var json = JSON.new()
	var parse_result = json.parse(level_data)
	
	if parse_result != OK:
		clear_rate_label.text = "解析错误"
		return
	
	var data = json.get_data()
	if not data is Dictionary:
		clear_rate_label.text = "格式错误"
		return
	
	# 尝试获取通过率和死亡数统计
	var pass_count = 0
	var death_count = 0
	
	# 从关卡数据中提取统计信息
	if data.has("pass_count"):
		pass_count = int(data["pass_count"])
	if data.has("death_count"):
		death_count = int(data["death_count"])
	
	# 计算通过率
	var total_attempts = pass_count + death_count
	var clear_rate = 0.0
	
	if total_attempts > 0:
		clear_rate = float(pass_count) / float(total_attempts) * 100.0
		clear_rate_label.text = "%.1f%%" % clear_rate
	else:
		clear_rate_label.text = "暂无数据"

# 加载关卡数据
func _load_level_data() -> String:
	var file_path = level_file_path
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		return ""
	
	var content = file.get_as_text()
	file.close()
	return content