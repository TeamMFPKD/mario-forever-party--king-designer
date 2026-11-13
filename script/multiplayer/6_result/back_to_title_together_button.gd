extends UiSoundButton

## 请求主机把整局拉回大厅。主机裁决后广播 LOBBY，各端统一切回标题页；
## 不再由按钮自己 rpc 后切场景，避免两端各切一次。


func _ready() -> void:
	super()
	pressed.connect(_on_button_pressed)


## 不能叫 `_on_pressed`：那会覆盖 UiSoundButton 播放按下音的虚方法。
func _on_button_pressed() -> void:
	MPManager.flow.request_return_to_lobby()
