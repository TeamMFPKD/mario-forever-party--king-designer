extends PlayerDependent

@export var path_to_parent: NodePath = ".."
@export var path_to_ani: NodePath = "../AnimatedSprite2D"

var ani: AnimatedSprite2D
var parent: Node2D
var player: Node2D:
	get:
		return get_player_body()

func _ready() -> void:
	parent = get_node(path_to_parent)
	ani = get_node(path_to_ani)
	
func _physics_process(_delta: float) -> void:
	var target: Node2D = player
	if target == null:
		return
	var look_up: bool = target.position.y > parent.position.y
	if ani.flip_v:
		look_up = not look_up
	ani.animation = "default" if look_up else "look_up"

	ani.flip_h = target.position.x < parent.position.x