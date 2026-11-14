extends Node

## 验证音效重复触发策略（移植自 MFGTE 的 SameStreamPolicy）。
## 无头运行，结果写 tools/audio_repeat_policy_probe_result.txt。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const RESULT_PATH: String = "res://tools/audio_repeat_policy_probe_result.txt"
const SOUND: String = "res://sound/level/coin.se.wav"


func _ready() -> void:
	var lines: Array[String] = []
	await _check_overlap(lines)
	await _check_restart(lines)
	_write(lines)
	get_tree().quit()


func _make(stream_key: AudioStream, policy: int, limit: int) -> ContinuousAudioStream:
	var player: ContinuousAudioStream = ContinuousAudioStream.new()
	player.stream = stream_key
	player.repeat_policy = policy
	player.max_same_stream_voices = limit
	player.overflow_volume_db = -60.0
	player.volume_db = 0.0
	add_child(player)
	return player


func _check_overlap(lines: Array[String]) -> void:
	var sound: AudioStream = load(SOUND) as AudioStream
	if sound == null:
		lines.append("overlap_load=false")
		return
	lines.append("overlap_load=true")

	var a: ContinuousAudioStream = _make(sound, ContinuousAudioStream.RepeatPolicy.OVERLAP, 2)
	var b: ContinuousAudioStream = _make(sound, ContinuousAudioStream.RepeatPolicy.OVERLAP, 2)
	var c: ContinuousAudioStream = _make(sound, ContinuousAudioStream.RepeatPolicy.OVERLAP, 2)

	a.play()
	b.play()
	await get_tree().process_frame
	await get_tree().process_frame
	lines.append("overlap_a_db=%.1f" % a.volume_db)
	lines.append("overlap_b_db=%.1f" % b.volume_db)
	lines.append("overlap_a_audible=%s" % str(a.volume_db > -60.0))
	lines.append("overlap_b_audible=%s" % str(b.volume_db > -60.0))

	c.play()
	await get_tree().process_frame
	await get_tree().process_frame
	lines.append("overlap_c_db=%.1f" % c.volume_db)
	lines.append("overlap_c_suppressed=%s" % str(c.volume_db <= -59.0))
	lines.append("overlap_all_playing=%s" % str(a.playing and b.playing and c.playing))

	# 停掉后音量应还原
	c.stop()
	await get_tree().process_frame
	await get_tree().process_frame
	lines.append("overlap_c_restored_db=%.1f" % c.volume_db)
	lines.append("overlap_c_restored=%s" % str(is_equal_approx(c.volume_db, 0.0)))

	a.queue_free()
	b.queue_free()
	c.queue_free()
	await get_tree().process_frame


func _check_restart(lines: Array[String]) -> void:
	var sound: AudioStream = load(SOUND) as AudioStream
	if sound == null:
		lines.append("restart_load=false")
		return
	lines.append("restart_load=true")

	var a: ContinuousAudioStream = _make(sound, ContinuousAudioStream.RepeatPolicy.RESTART, 8)
	var b: ContinuousAudioStream = _make(sound, ContinuousAudioStream.RepeatPolicy.RESTART, 8)

	a.play()
	await get_tree().process_frame
	await get_tree().process_frame
	lines.append("restart_a_playing_before=%s" % str(a.playing))

	b.play()
	await get_tree().process_frame
	await get_tree().process_frame
	lines.append("restart_a_playing_after=%s" % str(a.playing))
	lines.append("restart_b_playing=%s" % str(b.playing))
	lines.append("restart_cut_old=%s" % str(not a.playing and b.playing))

	a.queue_free()
	b.queue_free()
	await get_tree().process_frame


func _write(lines: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
