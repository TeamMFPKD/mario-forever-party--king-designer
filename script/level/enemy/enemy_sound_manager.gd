extends Node

class_name EnemySoundManager

@export var play_sound_stomped: bool = true
@export var play_sound_kicked: bool = true
@export var play_sound_bumped: bool = true

# 声音配置映射表
const SOUND_CONFIG := {
	"interaction_with_player": {
		"signal": "stomped",
		"sound_func": "play_stomped",
		"enabled": "play_sound_stomped"
	},
	"interaction_with_fireball": {
		"signal": "fireball_hitted",
		"sound_func": "play_kicked",
		"enabled": "play_sound_kicked"
	},
	"interaction_with_beetroot": {
		"signal": "beetroot_hitted",
		"sound_func": "play_kicked",
		"enabled": "play_sound_kicked"
	},
	"interaction_with_star": {
		"signal": "star_hitted",
		"sound_func": "play_kicked",
		"enabled": "play_sound_kicked"
	},
	"interaction_with_shell": {
		"signal": "shell_hitted",
		"sound_func": "play_kicked",
		"enabled": "play_sound_kicked"
	},
	"interaction_with_bump": {
		"signal": "bumped",
		"sound_func": "play_bumped",
		"enabled": "play_sound_bumped"
	},
	"interaction_with_crush": {
		"signal": "crushed_at",
		"sound_func": "play_kicked",
		"enabled": "play_sound_kicked"
	},
}

var sound_stomped: AudioStreamPlayer
var sound_kicked: AudioStreamPlayer
var sound_bumped: AudioStreamPlayer

func _ready() -> void:
	sound_stomped = get_node("Stomped") as AudioStreamPlayer
	sound_kicked = get_node("Kicked") as AudioStreamPlayer
	sound_bumped = get_node("Bumped") as AudioStreamPlayer

	var parent = get_parent()
	
	# 自动连接所有声音组件信号
	for meta_name in SOUND_CONFIG:
		var config = SOUND_CONFIG[meta_name]
		var enabled: bool = get(config["enabled"])
		
		if enabled and parent.has_meta(meta_name):
			var interaction = parent.get_meta(meta_name)
			var signal_name: String = config["signal"]
			var sound_func: String = config["sound_func"]
			
			if interaction.has_signal(signal_name):
				#interaction.connect(signal_name, call.bind(sound_func))
				interaction.connect(signal_name, Callable(self, sound_func))

func play_stomped(_hit_position : Vector2) -> void:
	sound_stomped.play()

func play_kicked(_hit_position : Vector2) -> void:
	sound_kicked.play()

func play_bumped(_hit_position : Vector2) -> void:
	sound_bumped.play()
