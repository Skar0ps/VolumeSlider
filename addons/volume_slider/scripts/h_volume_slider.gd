## A horizontal slider that controls the volume of a specific audio bus.
##
## This node extends [HSlider] to automatically manage the volume of an audio bus
## specified by [member bus_name]. It converts the linear slider value (0-100)
## to the logarithmic dB scale required by the [AudioServer].
## It also handles muting the bus when the slider is at its minimum value.
@icon("res://addons/volume_slider/icons/HVolumeSlider.svg")
@tool
extends HSlider
class_name HVolumeSlider

## Emitted when the slider's value changes.
## Passes the new volume in decibels ([param volume_db]) as an argument.
signal volume_changed(volume_db)

## The name of the audio bus to control.
## This list is populated dynamically from the project's audio bus layout.
var bus_name : String = "Master"

func _get_property_list():
	var property_list = []
	var bus_names = []
	for i in range(AudioServer.bus_count):
		bus_names.append(AudioServer.get_bus_name(i))
	
	if bus_names.is_empty():
		bus_names.append("Master")

	property_list.append({
		"name": "bus_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(bus_names)
	})
	return property_list

## Called when the slider's value is changed by the user.
## Converts the linear value to dB, mutes if necessary, and updates the bus volume.
func _value_changed(new_value:float):
	var bus = AudioServer.get_bus_index(bus_name)
	if bus != -1:
		AudioServer.set_bus_mute(bus,new_value <= min_value)
		var volume_db = linear_to_db(new_value/max(max_value,1))
		emit_signal("volume_changed",volume_db)
		AudioServer.set_bus_volume_db(bus,volume_db)
	else:
		push_error("No audio bus with name : "+bus_name)
