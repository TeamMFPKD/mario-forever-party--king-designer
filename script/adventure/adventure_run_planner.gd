class_name AdventureRunPlanner
extends RefCounted

## 从池子里按权重无放回抽关。
## 权重偏向低样本关卡，让随机团也能帮忙采样。

const PREFER_LOW_SAMPLE: float = 3.0


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


static func _weight(stat: AdventureLevelStat, prefer_low_sample: bool) -> float:
	if not prefer_low_sample:
		return 1.0
	var n: float = float(stat.solo_attempt)
	var m: float = float(stat.online_attempt())
	return 1.0 + PREFER_LOW_SAMPLE / (1.0 + n + m / 4.0)
