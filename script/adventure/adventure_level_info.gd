extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 百人团游玩时左侧的关卡信息面板。
##
## 样式沿用 history play 右侧信息卡（ui_panel 半透明底 + ui_label 白字描边），
## 内容为「这一关」在 adventure.ini 里的单人累计：
##   当前关卡 / 本关死亡数 / 本关通过数 / 本关跳过数（只算软跳过）
## 命数固定显示在面板最上方，图标取 mario_small walk 动画的第 3 帧（帧索引 2，atlas 32,0）。

@export var lives_label: Label
@export var level_value: Label
@export var death_value: Label
@export var pass_value: Label
@export var skip_value: Label

const LIVES_CAP: int = 100

@onready var _info_margin: MarginContainer = $UiMarginContainer/InfoMargin


func _ready() -> void:
	Adventure.run_changed.connect(_refresh)
	_refresh()
	_fit_height.call_deferred()


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
	death_value.text = str(int(stats.get("solo_death", 0)))
	pass_value.text = str(int(stats.get("solo_pass", 0)))
	# 只统计「我打不过」的软跳过，不含「本关不可能通过」的永久排除
	skip_value.text = str(int(stats.get("solo_skip_soft", 0)))
	_fit_height.call_deferred()


## 面板高度贴合内容：外层 8px 上下留白 + 内容最小高度。
func _fit_height() -> void:
	if _info_margin == null:
		return
	var content_height: float = _info_margin.get_combined_minimum_size().y
	if content_height > 0.0:
		size = Vector2(size.x, content_height + 16.0)
