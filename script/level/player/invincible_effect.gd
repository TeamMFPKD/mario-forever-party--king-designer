extends AnimatedSprite2D

var _animated_sprite_2d: AnimatedSprite2D
var _rng = RandomNumberGenerator.new()

func _ready():
	_animated_sprite_2d = get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func _physics_process(delta):
	if _animated_sprite_2d == null:
		return
	if not visible:
		return
	
	sprite_frames = _animated_sprite_2d.sprite_frames
	animation = _animated_sprite_2d.animation
	frame = _animated_sprite_2d.frame
	flip_h = _animated_sprite_2d.flip_h
	modulate = Color(_rng.randf(), _rng.randf(), _rng.randf(), 1.0)

func _on_starman_start() -> void:
	visible = true

func _on_starman_end() -> void:
	visible = false
	