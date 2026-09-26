extends AudioStreamPlayer

# 这里是一个补丁
# 不知道为什么 Edit 刚开始的时候会播放放置物品的音效
# 总之神秘 AI（
# 所以这里加了一个帧末才连接信号的延迟

func _ready() -> void:
	var fc: Callable = func() -> void:
		var level_control: LevelControl = get_parent()
		level_control.play_sound_place.connect(play)
	fc.call_deferred()
