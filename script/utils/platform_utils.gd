extends Node

class_name PlatformUtils

## 调试用平台伪装（仅 debug 构建生效，release 导出自动失效）。
## 用法：PlatformUtils.set_debug_platform("Android")
##   或命令行：-- --fake-platform=android
##   或环境变量：MFMP_FAKE_PLATFORM=android
static var _debug_platform_name: String = ""

# 伪装成手机时，桌面鼠标要能驱动手机 UI，需要临时改这两个输入模拟开关。
static var _emulation_applied: bool = false
static var _saved_emulate_touch_from_mouse: bool = false
static var _saved_emulate_mouse_from_touch: bool = true

# autoload 阶段先应用一次，后续场景/控件 _ready 就能收到触摸事件。
func _ready() -> void:
	_apply_debug_input_emulation()
	if _emulation_applied:
		Log.i("PlatformUtils", ["fake mobile: emulate_touch_from_mouse ON"])

# 设置伪装平台；导出 release 后直接忽略，避免线上被误用。
static func set_debug_platform(platform_name: String) -> void:
	if not OS.is_debug_build():
		return
	_debug_platform_name = _normalize_platform(platform_name)
	_apply_debug_input_emulation()

# 清除伪装平台，恢复到真实平台。
static func clear_debug_platform() -> void:
	_debug_platform_name = ""
	_restore_debug_input_emulation()

# 当前是否处于“伪装成手机”的状态（不含真实 Android/iOS）。
static func _is_faking_mobile() -> bool:
	if not OS.is_debug_build():
		return false
	var forced: String = _debug_platform_name
	if forced.is_empty():
		forced = _normalize_platform(_fake_platform_from_launch())
	return forced == "Android" or forced == "iOS"

# 打开鼠标→触摸模拟：桌面点虚拟按键会变成 InputEventScreenTouch。
static func _apply_debug_input_emulation() -> void:
	if _emulation_applied or not _is_faking_mobile():
		return
	_saved_emulate_touch_from_mouse = Input.is_emulating_touch_from_mouse()
	_saved_emulate_mouse_from_touch = Input.is_emulating_mouse_from_touch()
	Input.set_emulate_touch_from_mouse(true)
	Input.set_emulate_mouse_from_touch(true)
	_emulation_applied = true

# 退出伪装时还原，避免影响桌面端正常操作。
static func _restore_debug_input_emulation() -> void:
	if not _emulation_applied:
		return
	Input.set_emulate_touch_from_mouse(_saved_emulate_touch_from_mouse)
	Input.set_emulate_mouse_from_touch(_saved_emulate_mouse_from_touch)
	_emulation_applied = false

# 把命令行/环境变量里的小写平台名规范成 OS.get_name() 的写法。
static func _normalize_platform(platform_name: String) -> String:
	match platform_name.to_lower():
		"android":
			return "Android"
		"ios":
			return "iOS"
		"windows":
			return "Windows"
		"linux":
			return "Linux"
		"macos":
			return "macOS"
		"web":
			return "Web"
	return platform_name

# 从启动参数/环境变量读取伪装平台，返回空串表示没配。
static func _fake_platform_from_launch() -> String:
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--fake-platform="):
			return arg.trim_prefix("--fake-platform=")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fake-platform="):
			return arg.trim_prefix("--fake-platform=")
	return OS.get_environment("MFMP_FAKE_PLATFORM")

# 判断是否为桌面端平台
static func is_desktop_platform() -> bool:
	var platform_name: String = get_platform_name()
	
	# 桌面端平台
	var desktop_platforms: Array[String] = ["Windows", "Linux", "macOS", "X11"]
	
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
	var platform_name: String = get_platform_name()

	# 移动端平台
	var mobile_platforms: Array[String] = ["Android", "iOS"]

	return platform_name in mobile_platforms

# 获取当前平台名称（调试伪装优先，其次启动参数，最后真实平台）
static func get_platform_name() -> String:
	if OS.is_debug_build():
		if not _debug_platform_name.is_empty():
			return _debug_platform_name
		var forced: String = _normalize_platform(_fake_platform_from_launch())
		if not forced.is_empty():
			return forced
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
	var info: Dictionary = {
		"name": get_platform_name(),
		"is_desktop": is_desktop_platform(),
		"is_mobile": is_mobile_platform()
	}
	
	# 添加Web平台的详细信息
	if info["name"] == "Web":
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