extends Node

## 本机多开联机测试的启动参数解析（autoload 名：MpTest）。
##
## 参数既可以从引擎参数（编辑器 “自定义运行实例” 里直接填的参数）读，
## 也可以从 `--` 之后的用户参数里读，两边都认。
##
## 约定参数：
##   --mp-role=host|join
##   --mp-name=<玩家名>
##   --mp-slot=1|2|3   （仅命名：强制 test1/2/3）
##   --mp-ip=<主机地址>
##   --mp-port=<端口>
##   --mp-win=<宽>x<高>+<x>+<y>
##   --mp-pad=<手柄设备号>
##   --mp-no-ready-timeout
##   --mp-auto-ready
##   --mp-auto-start
##   --mp-expect=<人数>
##   --mp-edit-seconds=<秒>
##   --mp-auto-exit

## 合并引擎参数与 `--` 之后的用户参数，避免调用方关心参数从哪来。
func args() -> PackedStringArray:
	var merged: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_args():
		merged.append(arg)
	for arg: String in OS.get_cmdline_user_args():
		merged.append(arg)
	return merged

func has(flag: String) -> bool:
	return args().has(flag)

## 读取 `key=value` 形式的参数，找不到时返回 default_value。
func get_value(key: String, default_value: String = "") -> String:
	var prefix: String = key + "="
	for arg: String in args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return default_value

## 是否是本测试启动器拉起来的实例（普通启动返回 false）。
func is_test_launch() -> bool:
	var role: String = get_value("--mp-role")
	return role == "host" or role == "join"
