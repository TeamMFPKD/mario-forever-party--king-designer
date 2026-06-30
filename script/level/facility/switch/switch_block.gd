class_name SwitchBlock

extends StaticBody2D

signal free_of_overlap

@export var is_dotted_at_start: bool = false

var origin_collision_layer: int
var animated_sprite: AnimatedSprite2D
var switch_status: SwitchStatus
var overlapped_with_player: bool = false

func _ready() -> void:
	origin_collision_layer =  collision_layer
	animated_sprite = get_node("AnimatedSprite2D")
	_get_or_create_switch_status()

func _physics_process(_delta: float) -> void:
	var was_overlapped = overlapped_with_player
	overlapped_with_player = get_meta("overlapped_with_player", false)
	set_meta("overlapped_with_player", false)

	if was_overlapped and not overlapped_with_player:
		emit_signal("free_of_overlap")

func _get_or_create_switch_status() -> void:
	var fc = func():
		switch_status = get_tree().get_first_node_in_group("switch_status")
		if switch_status:
			# Update switch status at start
			_on_switch_switched()
			switch_status.switched.connect(_on_switch_switched)
			return
		switch_status = SwitchStatus.new()
		switch_status.switched.connect(_on_switch_switched)
		switch_status.add_to_group("switch_status")
		add_sibling(switch_status)
		# Update switch status at start
		_on_switch_switched()
	fc.call_deferred()

func _on_switch_switched() -> void:
	if not switch_status:
		return

	if overlapped_with_player:
		await self.free_of_overlap

	animated_sprite.animation = "off" if switch_status.is_on else "on"

	var set_solid_status = switch_status.is_on != is_dotted_at_start
	if set_solid_status:
		_set_solid()
	else:
		_set_dotted()

func _set_solid() -> void:
	collision_layer = origin_collision_layer

func _set_dotted() -> void:
	collision_layer = origin_collision_layer & ~1
