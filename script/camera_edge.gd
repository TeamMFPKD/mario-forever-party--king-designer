extends Line2D

var level_camera : Camera2D

func _ready() -> void:
	level_camera = get_tree().get_first_node_in_group("level_camera") as LevelCamera
	level_camera.limit_changed.connect(_on_camera_limit_changed)

func _on_camera_limit_changed(top: int, left: int, right: int, bottom: int) -> void:
	points = [
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom)
	]
