extends PlayerDependent

@export var _animated_sprite_2d: AnimatedSprite2D

var _parent: Node2D
var _origin_position_y: float
var _player_animation_sprite: AnimatedSprite2D
var _move: bool
var _phase: float

func _ready() -> void:
    _parent = get_parent() as Node2D
    _origin_position_y = _parent.position.y

func _on_player_injected(body: Node2D) -> void:
    _player_animation_sprite = body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func _physics_process(delta: float) -> void:
    var player: Node2D = get_player_body()
    if _parent == null or player == null or _player_animation_sprite == null:
        return
    
    if _parent.position.x > player.position.x:
        _move = (_player_animation_sprite.flip_h == true)
    else:
        _move = (_player_animation_sprite.flip_h == false)
    
    # Animation
    if not _move:
        _animated_sprite_2d.animation = "default"
    else:
        _animated_sprite_2d.animation = "track"
    
    if not _move:
        return
    
    # x 运动
    if _parent.position.x > player.position.x:
        _parent.position.x -= 48 * delta
    if _parent.position.x < player.position.x:
        _parent.position.x += 48 * delta
    
    # y 运动
    _parent.position.y = _origin_position_y - sin(_phase) * 30.0
    _phase += 2.4 * delta
    _parent.position.y = _origin_position_y + sin(_phase) * 30.0
    
    if _origin_position_y < player.position.y:
        _origin_position_y += 0.2
    if _origin_position_y > player.position.y:
        _origin_position_y -= 0.2