extends Area2D

var speed_y = -8.0
var obtained: bool = false:
	set(value):
		obtained = value
		if obtained:
			remove_from_group("pink_coin")
			$CollisionShape2D.disabled = true
			$AnimatedSprite2D.speed_scale = 8.0
var origin_pos_y: float

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	origin_pos_y = global_position.y

func _on_body_entered(_body: Node) -> void:
	obtained = true

func _physics_process(_delta):
	if not obtained:
		return
	global_position.y += speed_y
	speed_y += 0.6
	if global_position.y > origin_pos_y:
		queue_free()
