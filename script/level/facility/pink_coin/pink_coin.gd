extends Area2D

var speed_y = -8.0
var obtained: bool = false:
	set(value):
		obtained = value
		if obtained:
			remove_from_group("pink_coin")
			collision_mask =0
			$AnimatedSprite2D.speed_scale = 8.0
var origin_pos_y: float

var pink_coin_manager: PinkCoinManager

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	origin_pos_y = global_position.y
	pink_coin_manager = get_tree().get_first_node_in_group("pink_coin_manager") as PinkCoinManager

func _on_body_entered(_body: Node) -> void:
	obtained = true
	if pink_coin_manager:
		pink_coin_manager.pink_coin_obtained()

func _physics_process(_delta):
	if not obtained:
		return
	global_position.y += speed_y
	speed_y += 0.6
	if global_position.y > origin_pos_y:
		queue_free()
