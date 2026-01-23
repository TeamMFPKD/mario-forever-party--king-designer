extends Control

func _ready() -> void:
    # 连接视口尺寸变化信号
    get_viewport().size_changed.connect(_on_viewport_size_changed)
    # 初始调用一次
    _on_viewport_size_changed()

func _on_viewport_size_changed() -> void:
    # 获取当前视口
    var viewport = get_viewport()
    
    # 获取GameRoomSize相对于Room节点的变换
    # Room是Node2D根节点，GameRoomSize是它的直接子节点
    var room_node = get_parent()  # Room节点
    var viewport_transform = viewport.get_canvas_transform()
    
    # 计算GameRoomSize在Room节点坐标系中的位置和尺寸
    # 我们需要让GameRoomSize填充整个Room节点的可见区域
    var visible_rect = viewport.get_visible_rect()
    
    # 将视口可见区域转换到Room节点的坐标系
    var room_position = viewport_transform.affine_inverse() * visible_rect.position
    var room_size = visible_rect.size / viewport_transform.get_scale()
    
    # 设置GameRoomSize的位置和尺寸
    position = room_position
    size = room_size
    
    # 调试输出
    #print("Viewport size: ", viewport.size)
    #print("Visible rect: ", visible_rect)
    #print("Room position: ", room_position)
    #print("Room size: ", room_size)
    #print("Control position: ", position)
    #print("Control size: ", size)
	