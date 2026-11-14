extends Node

## 验证「喜欢的关卡」池能读到收藏索引里的关卡（新版收藏只登记文件名，
## .lvl 正本在 user:// 根目录），而不是只扫收藏目录。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const RESULT_PATH: String = "res://tools/adventure_liked_pool_probe_result.txt"


func _ready() -> void:
	var lines: Array[String] = []
	var liked_names: Array[String] = LikedCourses.get_files()
	lines.append("index_count=%d" % liked_names.size())

	var missing: int = 0
	for file_name: String in liked_names:
		if not FileAccess.file_exists(LikedCourses.level_path(file_name)):
			missing += 1
	lines.append("index_missing_files=%d" % missing)

	var liked: Dictionary = AdventurePoolBuilder.build_isolated("liked", Adventure.store.path)
	var liked_stats: Array = liked.get("stats", [])
	lines.append("liked_pool=%d" % liked_stats.size())

	var all: Dictionary = AdventurePoolBuilder.build_isolated("all", Adventure.store.path)
	var all_stats: Array = all.get("stats", [])
	lines.append("all_pool=%d" % all_stats.size())

	var bad_path: int = 0
	for stat: AdventureLevelStat in liked_stats:
		if not FileAccess.file_exists(stat.path):
			bad_path += 1
	lines.append("liked_bad_paths=%d" % bad_path)

	# 旧逻辑只看收藏目录里的 .lvl 副本（新版收藏已不再复制），作为回归对照。
	var legacy_dir_lvl: int = 0
	var liked_dir: DirAccess = DirAccess.open("user://liked courses")
	if liked_dir != null:
		for file_name: String in liked_dir.get_files():
			if file_name.ends_with(".lvl"):
				legacy_dir_lvl += 1
	lines.append("legacy_dir_lvl=%d" % legacy_dir_lvl)

	var typed: Array[AdventureLevelStat] = []
	for stat: AdventureLevelStat in liked_stats:
		typed.append(stat)
	var tier_info: Dictionary = AdventureTierCalculator.assign_tiers(typed)
	var counts: Array = tier_info.get("counts", [])
	lines.append("tier_sampled=%d" % int(tier_info.get("sampled", 0)))
	lines.append("tier_counts=%s" % str(counts))
	lines.append("tier_selectable=%s" % str(tier_info.get("selectable", false)))
	lines.append("liked_ok=%s" % str(liked_stats.size() > 0 and bad_path == 0))

	_write(lines)
	get_tree().quit()


func _write(lines: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
