extends Node

## 探针：验证「从未被抽到过」关卡的抽取权重。
##
## 用真实的 AdventureRunPlanner / AdventureLevelStat / AdventureTierCalculator 代码，
## 不复制公式，测的就是线上那份实现。
##
## 输出两部分：
##   1. 不同 NEVER_DRAWN_BONUS 下，首抽命中「从未抽到过」关卡的概率
##   2. 指定档位（tier>0）时，这些关卡还能不能进候选池

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const OUT: String = "res://tools/adventure_draw_weight_probe_result.txt"

var _log: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	var fresh: int = 86
	var drawn: int = 1044
	var stats: Array[AdventureLevelStat] = _make_pool(fresh, drawn)
	AdventureTierCalculator.assign_tiers(stats)

	var fresh_count: int = 0
	var tier_hist: Dictionary = {}
	for s: AdventureLevelStat in stats:
		if not s.is_drawn():
			fresh_count += 1
			tier_hist[s.tier] = int(tier_hist.get(s.tier, 0)) + 1
	_log.append("pool=%d fresh=%d drawn=%d" % [stats.size(), fresh_count, drawn])
	_log.append("fresh_levels_tier_distribution=%s" % str(tier_hist))

	# 1) 现行倍率下，tier=0（随机档）首抽命中率
	_log.append("current_bonus=%s" % str(AdventureRunPlanner.NEVER_DRAWN_BONUS))
	var hit_tier0: int = 0
	var rounds: int = 300
	for i: int in range(rounds):
		var picked: Array[String] = AdventureRunPlanner.draw(stats, 0, 1, 1000 + i, true)
		if not picked.is_empty() and _is_fresh(stats, picked[0]):
			hit_tier0 += 1
	_log.append("tier0_first_draw_fresh_rate=%.2f%%" % (float(hit_tier0) / float(rounds) * 100.0))

	# 2) tier=3（玩家当前设置）时，候选池里还剩几个 fresh
	var tier3_pick: Array[String] = AdventureRunPlanner.draw(stats, 3, 10, 42, true)
	var tier3_fresh: int = 0
	for k: String in tier3_pick:
		if _is_fresh(stats, k):
			tier3_fresh += 1
	_log.append("tier3_draw_size=%d" % tier3_pick.size())
	_log.append("tier3_fresh_in_draw=%d" % tier3_fresh)

	var all_tier3: int = 0
	for s: AdventureLevelStat in stats:
		if s.tier == 3:
			all_tier3 += 1
	_log.append("tier3_candidate_pool=%d" % all_tier3)

	# 断言：随机档首抽命中「从未抽到过」的概率必须 ≈100%
	var ok_fresh: bool = float(hit_tier0) / float(rounds) >= 0.99
	_log.append("assert_tier0_near_absolute=%s" % str(ok_fresh))
	# 断言：固定档位下这些关卡进不了候选池（独立问题，见 docs 待办）
	_log.append("note_tier_gt0_excludes_fresh=%s" % str(tier3_fresh == 0))

	_write()
	get_tree().quit()


## 造一个和玩家真实池同分布的池：drawn 的关卡有不同 attempt（权重 1.1~3.4），
## fresh 的关卡 attempt/online 全为 0。
func _make_pool(fresh: int, drawn: int) -> Array[AdventureLevelStat]:
	var out: Array[AdventureLevelStat] = []
	for i: int in range(fresh):
		var s: AdventureLevelStat = AdventureLevelStat.new()
		s.key = "fresh_%03d.lvl" % i
		s.file_exists = true
		s.solo_attempt = 0
		s.solo_pass = 0
		s.solo_drawn = 0
		out.append(s)
	for i: int in range(drawn):
		var s: AdventureLevelStat = AdventureLevelStat.new()
		s.key = "drawn_%04d.lvl" % i
		s.file_exists = true
		# 真实池里已露面关的 attempt 分布：少量高样本、多数低样本
		var a: int = 1 + (i % 12)
		s.solo_attempt = a
		s.solo_pass = a >> 1
		s.solo_drawn = 1
		s.online_pass = i % 5
		s.online_death = i % 3
		out.append(s)
	return out


func _is_fresh(stats: Array[AdventureLevelStat], key: String) -> bool:
	for s: AdventureLevelStat in stats:
		if s.key == key:
			return not s.is_drawn()
	return false


func _write() -> void:
	var f: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		return
	for line: String in _log:
		f.store_line(line)
	f.close()
