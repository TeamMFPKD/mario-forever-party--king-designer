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
## 只统计「我打不过」的软跳过，不含「本关不可能通过」的硬排除
var solo_skip_soft: int = 0
var solo_last: int = 0
## 被百人团抽进团的次数。开团时整批写入、无尽每抽一关记一次，
## 所以它衡量的是「被选中过」，不等于「真的打到了」——固定团里后面的关卡
## 可能还没轮到就放弃。抽取权重用它判断「这关有没有露过面」。
var solo_drawn: int = 0

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


## 是否已经被百人团抽到过。
## 老存档没有 solo_drawn 字段（默认 0），所以再用「有没有样本」兜底：
## 有任何一次 attempt 就说明它一定进过团，不能算「从没抽到过」。
func is_drawn() -> bool:
	return solo_drawn > 0 or total_attempt() > 0


func fail_count() -> int:
	return maxi(0, solo_attempt - solo_pass - solo_skip)
