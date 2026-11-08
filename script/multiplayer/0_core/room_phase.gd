class_name RoomPhase
extends RefCounted

## 房间阶段。只有主机可以推进，客户端只接受 s2c_phase_changed 广播。
##
## NONE    未进房
## LOBBY   标题页 / 玩家列表
## EDIT    准备动画 + 编辑房间
## TRANSFER 关卡数据传输
## PLAY    游玩
## RESULT  结算

enum Phase {
	NONE = 0,
	LOBBY = 1,
	EDIT = 2,
	TRANSFER = 3,
	PLAY = 4,
	RESULT = 5,
}

const PHASE_NAMES: Dictionary = {
	Phase.NONE: "NONE",
	Phase.LOBBY: "LOBBY",
	Phase.EDIT: "EDIT",
	Phase.TRANSFER: "TRANSFER",
	Phase.PLAY: "PLAY",
	Phase.RESULT: "RESULT",
}

## 合法迁移表。主机推进阶段前会检查，避免网络乱序导致跳阶段。
const VALID_TRANSITIONS: Dictionary = {
	Phase.NONE: [Phase.LOBBY],
	Phase.LOBBY: [Phase.EDIT, Phase.NONE],
	Phase.EDIT: [Phase.TRANSFER, Phase.LOBBY],
	Phase.TRANSFER: [Phase.PLAY, Phase.LOBBY],
	Phase.PLAY: [Phase.RESULT, Phase.LOBBY],
	Phase.RESULT: [Phase.LOBBY],
}


static func name_of(phase: int) -> String:
	return str(PHASE_NAMES.get(phase, "UNKNOWN"))


static func can_transition(from_phase: int, to_phase: int) -> bool:
	var allowed: Array = VALID_TRANSITIONS.get(from_phase, [])
	return allowed.has(to_phase)


static func is_in_game(phase: int) -> bool:
	return phase == Phase.EDIT \
		or phase == Phase.TRANSFER \
		or phase == Phase.PLAY \
		or phase == Phase.RESULT
