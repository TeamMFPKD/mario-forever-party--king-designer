extends Node

## 百人团 BGM：挑战 / 挑战专家两首同时播放，按难度档交叉淡入淡出。
##
## 两首曲子都常驻 playing，切档只推音量：目标曲淡入、另一首淡出到静音，
## 这样切换难度时音乐不会中断。启停时机由 Adventure 统一调度，
## 本脚本只负责音量与播放状态。

## 淡入淡出的时长（秒）。太长会盖住切档反馈，太短听起来像硬切。
@export var crossfade_time: float = 0.9
## 淡出到这一音量视为静音；播放器保持 playing，随时可以淡回来。
@export var silent_db: float = -80.0
## 正在响的那首曲子的音量（0 dB = 原始音量）。
@export var active_db: float = 0.0

var _challenge: AudioStreamPlayer
var _expert: AudioStreamPlayer
## 当前应该响的曲子：0 = 挑战，1 = 挑战专家，-1 = 都没有。
var _active: int = -1
var _tween: Tween


func _ready() -> void:
	_challenge = $Challenge as AudioStreamPlayer
	_expert = $Expert as AudioStreamPlayer
	_force_loop(_challenge)
	_force_loop(_expert)
	if _challenge != null:
		_challenge.volume_db = silent_db
	if _expert != null:
		_expert.volume_db = silent_db


## 简单 / 普通（1、2 档）与随机档（0）用挑战，困难 / 超难（3、4 档）用挑战专家。
func play_tier(tier: int) -> void:
	if _challenge == null or _expert == null:
		return
	var want: int = 1 if tier >= 3 else 0
	_ensure_playing()
	if _active == want:
		return
	_active = want
	var target: AudioStreamPlayer = _expert if want == 1 else _challenge
	var other: AudioStreamPlayer = _challenge if want == 1 else _expert
	_crossfade_to(target, other)


## 百人团 BGM 是否正在接管音乐（BgmManager 据此不再启动随机曲）。
func is_active() -> bool:
	return _active >= 0


## 离开百人团：淡出后停掉两个播放器；fade_time <= 0 时立即停。
func stop_all(fade_time: float = 0.0) -> void:
	_kill_tween()
	_active = -1
	if _challenge == null or _expert == null:
		return
	if fade_time <= 0.0:
		_stop_players()
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_challenge, "volume_db", silent_db, fade_time)
	_tween.tween_property(_expert, "volume_db", silent_db, fade_time)
	_tween.chain().tween_callback(_stop_players)


func _ensure_playing() -> void:
	if not _challenge.playing:
		_challenge.play()
	if not _expert.playing:
		_expert.play()


func _crossfade_to(target: AudioStreamPlayer, other: AudioStreamPlayer) -> void:
	_kill_tween()
	var duration: float = maxf(crossfade_time, 0.01)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(target, "volume_db", active_db, duration)
	_tween.tween_property(other, "volume_db", silent_db, duration)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _stop_players() -> void:
	_challenge.stop()
	_expert.stop()
	_challenge.volume_db = silent_db
	_expert.volume_db = silent_db


## MP3 的导入参数是 loop=false（见 .import 的 params），这里兜底打开循环：
## 挑战 BGM 要一直响到下一关，不能播完就静音。
func _force_loop(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	var mp3: AudioStreamMP3 = player.stream as AudioStreamMP3
	if mp3 != null:
		mp3.loop = true
