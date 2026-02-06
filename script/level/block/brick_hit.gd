extends BlockHit

func is_breakable(collider: Node2D) -> bool:
	if collider.has_meta("player_suit"):
		var collide_player_suit = collider.get_meta("player_suit") as PlayerSuit
		if collide_player_suit.suit == PlayerSuit.SuitType.SMALL:
			return false
		else:
			return true
	else:
		return true
