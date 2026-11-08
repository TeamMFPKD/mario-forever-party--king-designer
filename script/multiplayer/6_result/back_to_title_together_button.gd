extends Button

## 请求主机把整局拉回大厅。主机裁决后广播 LOBBY，各端统一切回标题页；
## 不再由按钮自己 rpc 后切场景，避免两端各切一次。


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	MPManager.flow.request_return_to_lobby()
