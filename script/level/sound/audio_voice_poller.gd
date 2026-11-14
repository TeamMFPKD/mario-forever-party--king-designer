extends Node

## 音效并发压制轮询器（常驻节点，不挂在任何场景里）：
## 由 ContinuousAudioStream 首次入场时按需创建，挂在 SceneTree.Root 下常驻，
## 每帧集中遍历所有音效节点，捕捉 Playing 的上升沿（开始发声）与下降沿（停止发声）。
##
## 为什么不给每个音效节点各写一个 _physics_process：
## 关卡里砖块、敌人、道具各自带一个音效节点，动辄上百个，
## 逐节点回调纯属浪费；集中成 1 个回调 + 一次紧循环就够了。
##
## ProcessMode 保持 Inherit，与原先逐节点的回调一样随暂停停止。
func _process(_delta: float) -> void:
	ContinuousAudioStream.poll_all_playback()
