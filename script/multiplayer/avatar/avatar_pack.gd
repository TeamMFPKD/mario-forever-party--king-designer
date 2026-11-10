extends Resource

class_name AvatarPack

## 内置头像清单（数据源：res://sprite/avatar/avatar_pack.tres）。
##
## 现在有两种素材来源，**优先用 scenes**：
##
## 1. scenes（推荐）——每个头像一个 .tscn，内部可分层叠放（底色 / 主体 / 配件）；
##    运行时由 AvatarBaker 纯 CPU 合成为一张贴图，头像 id 取场景根节点的 avatar_id。
## 2. textures（旧）——单张贴图，头像 id 取贴图文件名（不含扩展名）。
##
## 新建头像场景的步骤：
## 1. 在 res://sprite/avatar/sources/ 下新建一个 Control 场景（144×144），
##    根节点挂 script/multiplayer/avatar/avatar_source.gd，填好 avatar_id；
## 2. 往里放 ColorRect（底色）与 TextureRect（素材），按子节点顺序自下而上叠加；
## 3. 把场景拖进下面的 scenes 数组。
##
## id 由素材自身决定（场景的 avatar_id / 贴图文件名），联机时按 id 同步，
## 因此改名等同于换一个新头像。数组顺序只影响选择器里左右切换的顺序。

## 分层头像场景（优先）
@export var scenes: Array[PackedScene] = []

## 单张贴图头像（旧数据，scenes 为空时使用）
@export var textures: Array[Texture2D] = []
