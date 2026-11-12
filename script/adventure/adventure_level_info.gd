extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 百人团游玩时左侧的关卡信息面板。
##
## 样式沿用 history play 右侧信息卡（ui_panel 半透明底 + ui_label 白字描边），
## 内容为「这一关」在 adventure.ini 里的单人累计：
##   当前关卡 / 本关通过数 / 本关死亡数 / 本关跳过数（只算软跳过）/ 个人通过率
## 命数固定显示在面板最上方，图标取 mario_small walk 动画的第 3 帧（帧索引 2，atlas 32,0）。
## 三个计数用 SVG 图标表示：旗杆=通过、骷髅=死亡、快进=跳过。

@export var lives_label: Label
@export var level_value: Label
@export var death_value: Label
@export var pass_value: Label
@export var skip_value: Label
@export var clear_rate_value: Label

const LIVES_CAP: int = 100


func _ready() -> void:
	Adventure.run_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not Adventure.is_running():
		return

	var run: Dictionary = Adventure.current_run
	var lives: int = int(run.get("lives_left", 0))
	lives_label.text = "× MAX" if lives >= LIVES_CAP else "× %d" % lives

	var index: int = int(run.get("index", 0)) + 1
	var total: int = int(run.get("total_levels", -1))
	# 定量团显示「第几关 / 总关数」，无尽团没有总数，只显示当前关
	if total > 0:
		level_value.text = "%d / %d" % [index, total]
	else:
		level_value.text = "%d" % index

	var stats: Dictionary = Adventure.current_level_stats()
	var passed: int = int(stats.get("solo_pass", 0))
	death_value.text = str(int(stats.get("solo_death", 0)))
	pass_value.text = str(passed)
	# 只统计「我打不过」的软跳过，不含「本关不可能通过」的永久排除
	skip_value.text = str(int(stats.get("solo_skip_soft", 0)))
	clear_rate_value.text = _format_clear_rate(stats)


## 个人通过率 = solo_pass / solo_attempt（口径见 docs/raid_mode §5.1）。
## 进入关卡就会 attempt+1，所以第一次进新关会是 0.0%；没有样本时显示 --。
func _format_clear_rate(stats: Dictionary) -> String:
	var attempt: int = int(stats.get("solo_attempt", 0))
	if attempt <= 0:
		return "--"
	var passed: int = int(stats.get("solo_pass", 0))
	var rate: float = float(passed) / float(attempt) * 100.0
	return "%.1f%%" % rate
