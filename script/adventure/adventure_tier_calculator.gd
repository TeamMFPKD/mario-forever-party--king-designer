class_name AdventureTierCalculator
extends RefCounted

## 个人分位分档。
##
## p_solo 来自 adventure.ini；p_online 来自 .lvl 的 pass_count/death_count。
## 联机只做先验：k 最多相当于 K_MAX 次个人尝试。

const MIN_SAMPLED: int = 16
const MIN_TIER_LEVELS: int = 3
const K_MAX: float = 4.0
const M_HALF: float = 10.0
const P_MIN: float = 0.02
const P_MAX: float = 0.98


static func difficulty_for(stat: AdventureLevelStat) -> float:
	var n: int = stat.solo_attempt
	var m: int = stat.online_attempt()
	var p_solo: float = (float(stat.solo_pass) + 1.0) / (float(n) + 2.0)
	var p_online: float = (float(stat.online_pass) + 1.0) / (float(m) + 2.0)
	var k: float = K_MAX * float(m) / (float(m) + M_HALF)
	var p: float = p_online
	if n > 0:
		p = (float(stat.solo_pass) + k * p_online) / (float(n) + k)
	p = clampf(p, P_MIN, P_MAX)
	return log((1.0 - p) / p)


static func assign_tiers(stats: Array[AdventureLevelStat]) -> Dictionary:
	var sampled: Array[AdventureLevelStat] = []
	for stat: AdventureLevelStat in stats:
		stat.difficulty = difficulty_for(stat)
		stat.tier = 0
		if stat.excluded or not stat.file_exists:
			continue
		if not stat.is_sampled():
			continue
		sampled.append(stat)

	sampled.sort_custom(_sort_less)

	var counts: Array[int] = [0, 0, 0, 0]
	var total: int = sampled.size()
	for index: int in range(total):
		var tier: int = clampi(floori(float(index) * 4.0 / float(total)) + 1, 1, 4)
		sampled[index].tier = tier
		counts[tier - 1] += 1

	var selectable: bool = total >= MIN_SAMPLED
	for count: int in counts:
		if count < MIN_TIER_LEVELS:
			selectable = false

	return {
		"sampled": total,
		"counts": counts,
		"selectable": selectable,
	}


static func levels_in_tier(stats: Array[AdventureLevelStat], tier: int) -> Array[AdventureLevelStat]:
	var result: Array[AdventureLevelStat] = []
	for stat: AdventureLevelStat in stats:
		if stat.excluded or not stat.file_exists:
			continue
		if stat.tier == tier:
			result.append(stat)
	return result


static func _sort_less(a: AdventureLevelStat, b: AdventureLevelStat) -> bool:
	if not is_equal_approx(a.difficulty, b.difficulty):
		return a.difficulty < b.difficulty
	if a.total_attempt() != b.total_attempt():
		return a.total_attempt() < b.total_attempt()
	return a.key < b.key
