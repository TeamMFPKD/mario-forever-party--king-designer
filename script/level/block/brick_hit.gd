extends BlockHit

func _ready() -> void:
	super._ready()
	set_meta("is_brick", true)

func is_breakable(collider: Node2D) -> bool:
	if collider.has_meta("player_suit"):
		var collide_player_suit: PlayerSuit = collider.get_meta("player_suit")
		if collide_player_suit.suit == PlayerSuit.SuitType.SMALL:
			return false
		else:
			return true
	else:
		return true
