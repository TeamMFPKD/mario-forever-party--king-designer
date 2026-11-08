extends Resource

class_name AvatarPack

## 内置头像清单（数据源：res://sprite/avatar/avatar_pack.tres）。
##
## 新增头像的步骤：
## 1. 把正方形 PNG 放进 res://sprite/avatar/（建议 168×168，画面画在圆形内，圆外保持透明）；
## 2. 打开 avatar_pack.tres，把 PNG 拖进下面的 textures 数组；
## 3. 头像 id 自动取贴图文件名（不含扩展名），联机时按 id 同步，因此改名等于换一个新头像。
##
## 数组顺序就是选择器里左右切换的顺序，第一个同时也是默认头像。
## 素材会被圆形 shader（shader/avatar_circle.gdshader）再裁一次，
## 所以就算画到了圆外，显示时也不会溢出。

@export var textures: Array[Texture2D] = []
