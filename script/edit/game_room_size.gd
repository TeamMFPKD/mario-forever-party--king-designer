extends Control

var viewport: Viewport
var visible_rect: Rect2

func _ready() -> void :

    viewport = get_viewport()

    visible_rect = viewport.get_visible_rect()


    viewport.size_changed.connect(_on_viewport_size_changed)

    _on_viewport_size_changed()


func _on_viewport_size_changed() -> void :

    viewport = get_viewport()

    #var room_node = get_parent()
    var viewport_transform: Transform2D = viewport.get_canvas_transform()

    visible_rect = viewport.get_visible_rect()

    var window: Window = get_window()

    if visible_rect.size.x < 1920 or visible_rect.size.y < 1080:
        position = Vector2(0, 0)
        size = Vector2(1920, 1080)

        window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

        window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

        window.content_scale_size = Vector2i(1920, 1080)
        ProjectSettings.set_setting("display/window/strech/mode", "visible_rect")
        print("[%s] [GameRoomSize] stretch mode" % Time.get_time_string_from_system()+ProjectSettings.get_setting("display/window/strech/mode"))
        return

    var room_position: Vector2 = viewport_transform.affine_inverse() * visible_rect.position
    var room_size: Vector2 = visible_rect.size / viewport_transform.get_scale()

    position = room_position
    size = room_size