## A horizontal slider that controls the volume of an audio bus.
##
## This node extends [HSlider] to automatically manage the volume of an audio bus specified by [member bus_name]. It converts the linear slider value (0-100)
## to the logarithmic dB scale required by the [AudioServer].
## It also handles muting the bus when the slider is at its minimum value.
@icon("res://addons/volume_slider/icons/HVolumeSlider.svg")
@tool
extends HSlider
class_name HVolumeSlider

## Emitted when the slider's value changes.
## Passes the new volume in decibels ([param volume_db]) as an argument.
signal volume_changed(volume_db: float)

## The name of the audio bus to control.
## This list is populated dynamically from the project's audio bus layout.
##[br][member ProjectSettings.audio/buses/default_bus_layout].
var bus_name : String = "Master" : set=set_bus_name

@export_group("Label Display")
## If [code]true[/code], uses a [Label] to display the current volume
@export_custom(PROPERTY_HINT_GROUP_ENABLE,"") var label_display : bool = false

## Label node used to display the volume
@export var display_label : Label : set=set_display_label

## If [code]true[/code], rounds the displayed volume to the nearest integer.
##[br]Ignored if [member rounded] is [code]true[/code].
@export var round_display_volume : bool = true :
	set(new_value):
		round_display_volume = new_value
		_update_label_text()
	get:
		if not rounded:
			return round_display_volume
		return rounded

## If [code]true[/code], updates the label to the volume even when inside the editor.
@export var update_label_in_editor : bool = false :
	set(new_value):
		update_label_in_editor = new_value
		_update_label_text()

@export_group("Save Volume")
## If [code]true[/code], saves the volume to the [ConfigFile] at the [member config_path]
@export_custom(PROPERTY_HINT_GROUP_ENABLE,"") var save_volume : bool = false

## Location of the [ConfigFile] where the volume will be saved.
##[br]Can also be modified in the [ProjectSettings] at
##[member ProjectSettings.addons/volume_slider/config_path].
@export_global_file("*.cfg") var config_path : String = VolumeUtils.DEFAULT_PATH :
	set(new_path):
		config_path = new_path
		VolumeUtils.set_config_path(new_path)
		var actual_config_path : String = VolumeUtils.get_config_path()
		if new_path == actual_config_path:
			print("Config path changed successful !")
		else:
			print("fuck it does not work at all")
	get():
		return VolumeUtils.get_config_path()

## If [code]true[/code], saves the volume for the bus when the user stops dragging the slider in the [ConfigFile] at [member config_path].
@export var save_on_drag_end : bool = true :
	set(new_value):
		save_on_drag_end = new_value
		_check_drag_ended_connection()

func _ready() -> void:
	if Engine.is_editor_hint():
		AudioServer.bus_layout_changed.connect(notify_property_list_changed)
	_check_drag_ended_connection()
	_sync_slider_with_bus()
	mouse_exited.connect(release_focus)

#region Helpers

## Connects or disconnects the drag_ended signal based on [member save_on_drag_end]
func _check_drag_ended_connection() -> void:
	if save_on_drag_end:
		if not drag_ended.is_connected(_on_drag_ended):
			drag_ended.connect(_on_drag_ended)
	else:
		if drag_ended.is_connected(_on_drag_ended):
			drag_ended.disconnect(_on_drag_ended)

## Synchronises the [member value] to the corresponding bus
func _sync_slider_with_bus() -> void:
	var bus_index : int = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		var volume_db : float = AudioServer.get_bus_volume_db(bus_index)
		if save_volume:
			volume_db = VolumeUtils.load_persisted_volume(bus_name, config_path)
		value = VolumeUtils.db_to_value(volume_db)

#endregion

# Called when the slider's value is changed by the user.
# Converts the linear value to dB, mutes if necessary, and updates the bus volume.
func _value_changed(new_value: float) -> void:
	_update_label_text()
	if Engine.is_editor_hint():
		return
	var volume_db : float = VolumeUtils.compute_bus_volume_db(bus_name, self, new_value)
	if is_nan(volume_db):
		return
	emit_signal("volume_changed", volume_db)

## Updates the [member display_label] text if the conditions are met
func _update_label_text() -> void:
	if Engine.is_editor_hint() and not update_label_in_editor:
		return
	if not label_display or not is_instance_valid(display_label):
		return
	
	var displayed_value : String = str(value)
	if round_display_volume or rounded:
		displayed_value = str(roundi(value))
	display_label.text = displayed_value

## Saves the volume on drag end if [member save_volume] is [code]true[/code], otherwise unused and disconnected
func _on_drag_ended(value_changed: bool) -> void:
	if save_volume and value_changed:
		VolumeUtils.save_persisted_volume(bus_name, config_path, VolumeUtils.value_to_db(value))

func _validate_property(property: Dictionary) -> void:
	match property.name:
		# Hide useless range properties for a volume slider
		"page","exp_edit","allow_lesser","allow_greater":
			property.usage = PROPERTY_USAGE_NO_EDITOR
		"round_display_volume":
			if rounded:
				property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY

# Used for displaying the dynamic dropdown of bus names in the inspector
func _get_property_list() -> Array[Dictionary]:
	#HACK : here to prevent the bus names from being included in the save group
	var empty_group : Dictionary[String,Variant] = {
			"name": "",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP
		}
	
	var property_list : Array[Dictionary] = [
		# Prevents bus_name from being in the Save Volume group
		empty_group,
		# Adds a dropdown with the current AudioBusLayout bus names
		VolumeUtils.get_bus_names_enum(),
		]
	
	return property_list

#region Setters

func set_bus_name(new_bus_name:String) -> void:
	if VolumeUtils.is_valid_bus(new_bus_name):
		bus_name = new_bus_name
	else:
		push_error('No bus found with name : "',new_bus_name,'"')

func set_display_label(new_label:Label) -> void:
	display_label = new_label
	_update_label_text()

func _set(property: StringName, value: Variant) -> bool:
	# Hides dynamically round_display_volume based on the state of rounded
	if property == "rounded":
		notify_property_list_changed()
		_update_label_text.call_deferred()
	return false

#endregion
