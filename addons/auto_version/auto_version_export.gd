@tool
extends EditorExportPlugin

func _export_begin(features, is_debug, path, flags):
    var datetime = Time.get_datetime_dict_from_system()
    var version_str = "v%04d%02d%02d_%02d%02d" % [datetime.year, datetime.month, datetime.day, datetime.hour, datetime.minute]
    ProjectSettings.set_setting("application/config/version", version_str)
    ProjectSettings.save()
    print("导出前自动更新版本号：", version_str)