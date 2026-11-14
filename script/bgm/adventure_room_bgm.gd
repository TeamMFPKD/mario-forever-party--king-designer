extends AudioStreamPlayer

## 百人团子页面（GAME OVER / GAME CLEAR / 「排除的关卡」）的专属 BGM。
##
## 进场时让挑战 BGM 淡出、关卡里的随机池 BGM 停掉，本曲淡入（不叠两套音乐），
## 场景销毁时随节点一起停止；回到舞台 / 游玩后由那些场景重新起各自的 BGM。

@export var fade_time: float = 0.6
@export var silent_db: float = -80.0

func _ready() -> void:
	Adventure.stop_bgm(fade_time)
	Adventure.stop_pool_bgm()
	volume_db = silent_db
	play()
	var tween: Tween = create_tween()
	tween.tween_property(self, "volume_db", 0.0, maxf(fade_time, 0.01))
