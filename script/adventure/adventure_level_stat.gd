class_name AdventureLevelStat
extends RefCounted

## 百人团关卡池里的一条关卡记录。
## 单人数据来自 adventure.ini；联机数据来自 .lvl 的 pass_count/death_count。

var key: String = ""
var path: String = ""
var fingerprint: String = ""
var file_exists: bool = false

var excluded: bool = false
var exclude_reason: String = ""

var solo_attempt: int = 0
var solo_pass: int = 0
var solo_death: int = 0
var solo_skip: int = 0
var solo_last: int = 0

var online_pass: int = 0
var online_death: int = 0

## 由 TierCalculator 填充。
var difficulty: float = 0.0
var tier: int = 0


func online_attempt() -> int:
	return online_pass + online_death


func total_attempt() -> int:
	return solo_attempt + online_attempt()


func is_sampled() -> bool:
	return total_attempt() > 0


func fail_count() -> int:
	return maxi(0, solo_attempt - solo_pass - solo_skip)
