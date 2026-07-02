extends Label

@export var player_mov: PlayerMovement
@export var player_node: CharacterBody2D

func _process(_delta) -> void:
	var up = player_node.up_direction
	var rot = rad_to_deg(up.angle()) + 90.0
	var velocity = player_node.velocity

	text = \
	"=== Position ===" + "\n" + \
	"pos:          " + str(snapped(player_node.position.x, 0.1)) + ", " + str(snapped(player_node.position.y, 0.1)) + "\n" + \
	"rotation:     " + str(snapped(player_node.rotation_degrees, 0.1)) + "\n" + \
	"" + "\n" + \
	"=== Speed (local frame) ===" + "\n" + \
	"speed_x:      " + str(snapped(player_mov.speed_x, 0.1)) + "\n" + \
	"speed_y:      " + str(snapped(player_mov.speed_y, 0.1)) + "\n" + \
	"target_speed: " + str(snapped(player_mov.target_speed, 0.1)) + "\n" + \
	"" + "\n" + \
	"=== World Velocity ===" + "\n" + \
	"vel.x:        " + str(snapped(velocity.x, 0.1)) + "\n" + \
	"vel.y:        " + str(snapped(velocity.y, 0.1)) + "\n" + \
	"vel.len:      " + str(snapped(velocity.length(), 0.1)) + "\n" + \
	"" + "\n" + \
	"=== Gravity State ===" + "\n" + \
	"is_on_triangle:        " + str(player_mov.is_on_triangle) + "\n" + \
	"is_switching_gravity:  " + str(player_mov.is_switching_gravity) + "\n" + \
	"target_gravity:        " + str(player_mov.target_gravity) + "\n" + \
	"rotate_with_up:        " + str(snapped(player_mov.rotate_with_up, 0.1)) + "\n" + \
	"up_direction:          " + str(snapped(up.x, 2)) + ", " + str(snapped(up.y, 2)) + "\n" + \
	"" + "\n" + \
	"=== Floor/Wall/Ceiling ===" + "\n" + \
	"is_on_floor:   " + str(player_node.is_on_floor()) + "\n" + \
	"is_on_wall:    " + str(player_node.is_on_wall()) + "\n" + \
	"is_on_ceiling: " + str(player_node.is_on_ceiling()) + "\n" + \
	"" + "\n" + \
	"=== Transport ===" + "\n" + \
	"is_in_pipe: " + str(player_mov.is_in_pipe) + "\n" + \
	"is_in_door: " + str(player_mov.is_in_door) + "\n" + \
	"" + "\n" + \
	"=== Misc ===" + "\n" + \
	"crouch:     " + str(player_mov.crouch) + "\n" + \
	"jumpable:   " + str(player_mov.jumpable) + "\n" + \
	"langtiao:   " + str(player_mov.langtiao) + "\n" + \
	"gravity:    " + str(snapped(player_mov.gravity_normal if not (player_mov.move_jump) else player_mov.gravity_hold_jump, 0.1)) + "\n"
