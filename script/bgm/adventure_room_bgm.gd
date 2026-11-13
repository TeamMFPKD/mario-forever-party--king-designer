extends AudioStreamPlayer

## 百人团子页面（GAME OVER / GAME CLEAR / 垃圾桶）的专属 BGM。
##
## 进场时让挑战 BGM 淡出、本曲淡入（两边同时交叉，不留静音空档），
## 场景销毁时随节点一起停止；回到舞台 / 游玩后由那些场景重新起挑战 BGM。

@export var fade_time: float = 0.6
@export var silent_db: float = -80.0

func _ready() -> void:
	# mp3 / ogg 的导入参数默认是 loop=false，结算页可能停留很久，这里统一兜底循环。
	var mp3: AudioStreamMP3 = stream as AudioStreamMP3
	if mp3 != null:
		mp3.loop = true
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true

	Adventure.stop_bgm(fade_time)
	volume_db = silent_db
	play()
	var tween: Tween = create_tween()
	tween.tween_property(self, "volume_db", 0.0, maxf(fade_time, 0.01))
