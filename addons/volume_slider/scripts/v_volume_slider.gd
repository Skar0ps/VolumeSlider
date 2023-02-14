## Vertical volume slider
@icon("res://addons/volume_slider/icons/VVolumeSlider.svg")
@tool
extends VSlider
class_name VVolumeSlider

signal volume_changed(volume)

@export var bus_name : String = "Master"

func _enter_tree():
	value_changed.connect(_on_value_changed)

func _on_value_changed(value):
	var bus = AudioServer.get_bus_index(bus_name)
	if bus != -1:
		AudioServer.set_bus_mute(bus,value <= min_value)
		var volume = linear_to_db(value/max(max_value,1))
		emit_signal("volume_changed",volume)
		AudioServer.set_bus_volume_db(bus,volume)
	else:
		push_error("No audio bus with name : "+bus_name)

