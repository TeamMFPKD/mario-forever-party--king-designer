extends Node

signal load_level

@export var debug_load: bool = false

func _ready() -> void:
	if not debug_load:
		return
	
	# Enable file drop handling
	get_viewport().files_dropped.connect(_on_files_dropped)

func _on_files_dropped(files: PackedStringArray) -> void:
	# Get the path of the first file dropped
	if files.size() > 0:
		var file_path = files[0]
		# Check if it's a level file
		if file_path.get_extension().to_lower() == "lvl":
			load_level.emit(file_path)
		else:
			print("[debug_load.gd] Dropped file is not a .lvl file: ", file_path)
	else:
		print("[debug_load.gd] No files dropped")