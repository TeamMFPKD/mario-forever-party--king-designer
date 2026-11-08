extends Timer

signal force_continue


func _ready() -> void:
	if not MPManager.net.is_server():
		return
	timeout.connect(_on_timeout)


func _on_timeout() -> void:
	force_continue.emit()
