extends Node

class_name PlatformUtils

# 判断是否为桌面端平台
static func is_desktop_platform() -> bool:
	var platform_name = OS.get_name()
	
	# 桌面端平台
	var desktop_platforms = ["Windows", "Linux", "macOS", "X11"]
	
	# 检查是否在桌面平台列表中
	if platform_name in desktop_platforms:
		return true
	
	# 特殊处理Web平台
	if platform_name == "Web":
		# Web平台需要进一步判断具体类型
		return _is_web_desktop()
	
	# 移动端平台（Android, iOS等）
	return false

# 判断是否为移动端平台
static func is_mobile_platform() -> bool:
	var platform_name = OS.get_name()
	
	# 移动端平台
	var mobile_platforms = ["Android", "iOS"]
	
	return platform_name in mobile_platforms

# 获取当前平台名称
static func get_platform_name() -> String:
	return OS.get_name()

# 私有函数：判断Web平台是否为桌面端
static func _is_web_desktop() -> bool:
	# 使用OS.has_feature()方法检测Web平台的具体类型
	
	# 检测是否为Windows上的Web
	if OS.has_feature("web_windows"):
		return true
	
	# 检测是否为Linux上的Web
	if OS.has_feature("web_linux"):
		return true
	
	# 检测是否为macOS上的Web
	if OS.has_feature("web_macos"):
		return true
	
	# 检测是否为Android上的Web
	if OS.has_feature("web_android"):
		return false
	
	# 检测是否为iOS上的Web
	if OS.has_feature("web_ios"):
		return false
	
	# 默认情况下，Web平台认为是桌面端
	return true

# 获取详细的平台信息
static func get_platform_info() -> Dictionary:
	var info = {
		"name": OS.get_name(),
		"is_desktop": is_desktop_platform(),
		"is_mobile": is_mobile_platform()
	}
	
	# 添加Web平台的详细信息
	if info.name == "Web":
		info["web_platform"] = _get_web_platform_detail()
	
	return info

# 私有函数：获取Web平台的详细类型
static func _get_web_platform_detail() -> String:
	if OS.has_feature("web_windows"):
		return "Web on Windows"
	elif OS.has_feature("web_linux"):
		return "Web on Linux"
	elif OS.has_feature("web_macos"):
		return "Web on macOS"
	elif OS.has_feature("web_android"):
		return "Web on Android"
	elif OS.has_feature("web_ios"):
		return "Web on iOS"
	else:
		return "Web (Unknown)"