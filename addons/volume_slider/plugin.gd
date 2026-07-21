@tool
extends EditorPlugin

const AUTOLOAD_NAME : String = "VolumeSliderBootstrap"
const AUTOLOAD_PATH : String = "res://addons/volume_slider/scripts/volume_slider_bootstrap.gd"

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
