extends Node
class_name FileDeleteHelper 

var paths: Array[String] = []
var thread: Thread

func start() -> void:
	thread = Thread.new()
	thread.start(_delete_thread)

func _delete_thread() -> void:
	for path in paths:
		if FileAccess.file_exists(path):
			var real_path := ProjectSettings.globalize_path(path)
			var err := OS.move_to_trash(real_path)
			if err != OK:
				push_error("[FileDeleteHelper] 删除失败: %s，错误码: %d" % [real_path, err])
			else:
				print("[FileDeleteHelper] 已删除: ", real_path)
		else:
			push_warning("[FileDeleteHelper] 文件不存在，跳过: %s" % path)
	# 删完后回主线程清理自身
	call_deferred("queue_free")