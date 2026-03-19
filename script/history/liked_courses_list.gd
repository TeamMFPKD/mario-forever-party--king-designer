extends GridContainer

@export var item_width: float = 448.0

func _ready() -> void:
    resized.connect(_update_columns)
    _update_columns()

func _update_columns() -> void:
    var cols = max(1, ceil(size.x / item_width))
    if columns != cols:
        columns = cols