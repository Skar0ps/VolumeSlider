@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type("HVolumeSlider","HSlider",preload("res://addons/volume_slider/scripts/h_volume_slider.gd"),load("res://addons/volume_slider/icons/HVolumeSlider.svg"))
	add_custom_type("VVolumeSlider","VSlider",preload("res://addons/volume_slider/scripts/v_volume_slider.gd"),load("res://addons/volume_slider/icons/VVolumeSlider.svg"))

func _exit_tree():
	remove_custom_type("HVolumeSlider")
	remove_custom_type("VVolumeSlider")
