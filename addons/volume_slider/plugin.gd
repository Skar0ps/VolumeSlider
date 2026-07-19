@tool
extends EditorPlugin

var inspector_plugin : EditorInspectorPlugin

func _enter_tree():
	add_custom_type("HVolumeSlider","HSlider",preload("res://addons/volume_slider/scripts/h_volume_slider.gd"),load("res://addons/volume_slider/icons/HVolumeSlider.svg"))
	add_custom_type("VVolumeSlider","VSlider",preload("res://addons/volume_slider/scripts/v_volume_slider.gd"),load("res://addons/volume_slider/icons/VVolumeSlider.svg"))
	inspector_plugin = preload("res://addons/volume_slider/editor/inspector_plugin.gd").new()
	add_inspector_plugin(inspector_plugin)

func _exit_tree():
	remove_custom_type("HVolumeSlider")
	remove_custom_type("VVolumeSlider")
	remove_inspector_plugin(inspector_plugin)

func _enable_plugin():
	# Adds the config_path to the project settings if not present
	if not ProjectSettings.has_setting(VolumeUtils.SETTING_PATH):
		ProjectSettings.set_setting(VolumeUtils.SETTING_PATH, VolumeUtils.DEFAULT_PATH)
		ProjectSettings.set_initial_value(VolumeUtils.SETTING_PATH, VolumeUtils.DEFAULT_PATH)
		ProjectSettings.add_property_info({
			"name": VolumeUtils.SETTING_PATH,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_GLOBAL_FILE,
			"hint_string": "*.cfg"
		})
		ProjectSettings.save()
