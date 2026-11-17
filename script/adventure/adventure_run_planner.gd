class_name AdventureRunPlanner
extends RefCounted

## 从池子里按权重无放回抽关。
## 权重偏向低样本关卡，让随机团也能帮忙采样；
## 并且再偏向「从没被百人团抽到过」的关卡，避免热门关反复出现、冷门关永远轮不到。

## 低样本加成：样本越少权重越大（分母里的常数项保证它有上限）。
const PREFER_LOW_SAMPLE: float = 3.0
## 「从没被抽到过」的额外倍率。乘在低样本权重之上，
## 所以一关只要露过一次面，权重就掉回普通档，把机会让给还没出现过的关卡。
##
## 4.0 → 8.0（2026-11-16）→ 100000.0（2026-11-17）：要让没露过面的关卡**近乎绝对优先**。
## 由于「没露过面」等价于 attempt 与 online 样本都是 0，这类关卡的基础权重恒为
## 1 + 3/(1+0+0) = 4.0，所以单抽命中率只由「未露面关数 × 4M」与「已露面关的权重和」之比决定。
## 取实测池（1130 关，其中 86 关未露面，已露面总权重约 1535）估算：
##   M=8      → 64.2%
##   M=1000   → 99.56%
##   M=100000 → 99.996%
## 即使只剩最后 1 关没露面（对 1535 的已露面权重和），M=100000 时仍有 4*100000/(4*100000+1535) = 99.6%。
## 再大就没有实测意义了：这里刻意保留「小概率仍抽到已露面关」，
## 而不是把它改成硬优先级——硬优先级会让同一批新导入的关卡被连续抽干，失去随机感。
const NEVER_DRAWN_BONUS: float = 100000.0


static func draw(
	stats: Array[AdventureLevelStat],
	tier: int,
	count: int,
	seed_value: int,
	prefer_low_sample: bool,
	exclude_keys: Array[String] = []
) -> Array[String]:
	var candidates: Array[AdventureLevelStat] = []
	for stat: AdventureLevelStat in stats:
		if stat.excluded or not stat.file_exists:
			continue
		if exclude_keys.has(stat.key):
			continue
		if tier > 0 and stat.tier != tier:
			continue
		candidates.append(stat)

	var result: Array[String] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var draw_count: int = mini(count, candidates.size())

	for _index: int in range(draw_count):
		var total_weight: float = 0.0
		for stat: AdventureLevelStat in candidates:
			total_weight += _weight(stat, prefer_low_sample)
		if total_weight <= 0.0:
			break

		var target: float = rng.randf() * total_weight
		var chosen_index: int = candidates.size() - 1
		var accumulated: float = 0.0
		for index: int in range(candidates.size()):
			accumulated += _weight(candidates[index], prefer_low_sample)
			if target <= accumulated:
				chosen_index = index
				break

		result.append(candidates[chosen_index].key)
		candidates.remove_at(chosen_index)

	return result


## 单关注释：prefer_low_sample=false 时是均匀随机（权重恒为 1）。
static func _weight(stat: AdventureLevelStat, prefer_low_sample: bool) -> float:
	if not prefer_low_sample:
		return 1.0
	var n: float = float(stat.solo_attempt)
	var m: float = float(stat.online_attempt())
	var weight: float = 1.0 + PREFER_LOW_SAMPLE / (1.0 + n + m / 4.0)
	if not stat.is_drawn():
		weight *= NEVER_DRAWN_BONUS
	return weight
