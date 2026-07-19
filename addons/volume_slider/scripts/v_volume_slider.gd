## A vertical slider that controls the volume of an audio bus.
##
## This node extends [VSlider] to automatically manage the volume of an audio bus
## specified by [member bus_name]. It converts the linear slider value (0-100)
## to the logarithmic dB scale required by the [AudioServer].
## It also handles muting the bus when the slider is at its minimum value.
@icon("res://addons/volume_slider/icons/VVolumeSlider.svg")
@tool
extends VSlider
class_name VVolumeSlider

## Emitted when the slider's value changes.
## Passes the new volume in decibels ([param volume_db]) as an argument.
signal volume_changed(volume_db: float)

signal muted()

signal unmuted()

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
##[br]Changing this will modify [member ProjectSettings.addons/volume_slider/config_path].
@export_global_file("*.cfg") var config_path : String = VolumeUtils.DEFAULT_PATH :
	set(new_path):
		config_path = new_path
		VolumeUtils.set_config_path(new_path)
	get():
		return VolumeUtils.get_config_path()

## If [code]true[/code], saves the volume for the bus when the user stops dragging the slider in the [ConfigFile] at [member config_path].
@export var save_on_drag_end : bool = true :
	set(new_value):
		save_on_drag_end = new_value
		_check_drag_ended_connection()

@export_group("Accessibility")
@export_subgroup("Tooltip Display","tooltip_")
## If [code]true[/code], displays a tooltip showing the current volume when hovering the slider.
@export_custom(PROPERTY_HINT_GROUP_ENABLE,"") var tooltip_display : bool = false

## If [code]true[/code], includes the volume in decibels in the tooltip.
@export var tooltip_show_decibels : bool = false

## If [code]true[/code], includes the audio bus name in the tooltip.
@export var tooltip_show_bus_name : bool = false
@export_custom(PROPERTY_HINT_TYPE_STRING,"",PROPERTY_USAGE_EDITOR + PROPERTY_USAGE_READ_ONLY) var tooltip_preview : String :
	get():
		return _get_tooltip(Vector2.ZERO)


@export_group("")

## (Optionnal) Synchronize a mute button with this VolumeSlider
@export var mute_button : CheckBox :
	set(new_button):
		mute_button = new_button
		notify_property_list_changed()

## Creates a [ToggleButton] that will mute this slider volume
@export_tool_button("Create a mute button","AudioMute") var _mute_button_create : Callable :
	get(): return VolumeUtils.create_mute_button.bind(self, bus_name)

## Icon used for the grabber when the slider's bus is muted.
## Returns null if unset, use [method get_resolved_grabber_muted_icon] for display purposes.
@export_custom(PROPERTY_HINT_RESOURCE_TYPE,"Texture2D",PROPERTY_USAGE_STORAGE) var grabber_muted_icon : Texture2D :
	set(new_icon):
		grabber_muted_icon = new_icon
		_update_grabber_icon()

## Grabber icon override "cache" to prevent grabber_muted from discarding the user set grabber icon override.
var _saved_grabber_icon_override : Texture2D = null 

## Icon used for the grabber_highlight when the slider's bus is muted.
## Returns null if unset, use [method get_resolved_grabber_muted_highlight_icon] for display purposes.
@export_custom(PROPERTY_HINT_RESOURCE_TYPE,"Texture2D",PROPERTY_USAGE_STORAGE) var grabber_muted_highlight_icon : Texture2D :
	set(new_icon):
		grabber_muted_highlight_icon = new_icon
		_update_grabber_icon()

## Grabber highlight icon override "cache" to prevent grabber_muted_highlight from discarding the user set override.
var _saved_grabber_highlight_icon_override : Texture2D = null

func _init() -> void:
	value = 100.0

func _ready() -> void:
	if Engine.is_editor_hint():
		AudioServer.bus_layout_changed.connect(notify_property_list_changed)
		# lambda to ignore the signal arguments
		AudioServer.bus_renamed.connect(func(_a,_b,_c):notify_property_list_changed())
	_check_drag_ended_connection()
	_sync_slider_with_bus()
	
	if accessibility_name.is_empty():
		accessibility_name = "%s Volume Slider" % bus_name.capitalize()
	if accessibility_description.is_empty():
		accessibility_description = "Adjusts the %s audio bus volume, currently %.0f percent" % [bus_name, value]
	
	mouse_exited.connect(release_focus)
	if is_instance_valid(mute_button):
		if not mute_button.toggled.is_connected(_on_mute_button_toggled):
			mute_button.toggled.connect(_on_mute_button_toggled)
		if not mute_button.tree_exited.is_connected(_on_mute_button_tree_exited):
			mute_button.tree_exited.connect(_on_mute_button_tree_exited)
		
		muted.connect(mute_button.set_pressed_no_signal.bind(true))
		unmuted.connect(mute_button.set_pressed_no_signal.bind(false))

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

func _on_mute_button_tree_exited() -> void:
	mute_button = null
	notify_property_list_changed()

func _on_mute_button_toggled(muted: bool) -> void:
	var current_bus_index : int = AudioServer.get_bus_index(bus_name)
	if current_bus_index == -1:
		push_error("No audio bus with name: " + bus_name)
		return
	AudioServer.set_bus_mute(current_bus_index, muted)
	_update_grabber_icon()

func is_muted() -> bool:
	if not VolumeUtils.is_valid_bus(bus_name):
		return false
	
	var bus_index : int = AudioServer.get_bus_index(bus_name)
	var is_bus_mute : bool = AudioServer.is_bus_mute(bus_index)
	if Engine.is_editor_hint():
		return value <= min_value or is_bus_mute
	return is_bus_mute

## Returns the icon actually used for the grabber when muted, resolving theme fallbacks if unset.
## Used both for the actual grabber rendering and for the inspector's fallback preview.
func get_resolved_grabber_muted_icon() -> Texture2D:
	if grabber_muted_icon != null:
		return grabber_muted_icon
	if has_theme_icon(&"grabber_muted", &"VVolumeSlider"):
		return get_theme_icon(&"grabber_muted", &"VVolumeSlider")
	if has_theme_icon(&"grabber", &"VSlider"):
		return get_theme_icon(&"grabber", &"VSlider")
	return null

## Returns the icon actually used for grabber_highlight when muted, resolving theme fallbacks if unset.
func get_resolved_grabber_muted_highlight_icon() -> Texture2D:
	if grabber_muted_highlight_icon != null:
		return grabber_muted_highlight_icon
	if has_theme_icon(&"grabber_muted_highlight", &"VVolumeSlider"):
		return get_theme_icon(&"grabber_muted_highlight", &"VVolumeSlider")
	if has_theme_icon(&"grabber_highlight", &"VSlider"):
		return get_theme_icon(&"grabber_highlight", &"VSlider")
	return get_resolved_grabber_muted_icon()

#endregion

# Called when the slider's value is changed by the user.
# Converts the linear value to dB, mutes if necessary, and updates the bus volume.
func _value_changed(new_value: float) -> void:
	_update_label_text()
	# deferred to prevent it updating before we can know if the bus has been muted
	_update_grabber_icon.call_deferred()
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

func _update_grabber_icon() -> void:
	if not VolumeUtils.is_valid_bus(bus_name):
		return
	var _muted_icon : Texture2D = get_resolved_grabber_muted_icon()
	var _muted_highlight_icon : Texture2D = get_resolved_grabber_muted_highlight_icon()
	if _muted_icon == null:
		push_error("No muted icon has been set")
		return
	if is_muted():
		add_theme_icon_override("grabber", _muted_icon)
		add_theme_icon_override("grabber_highlight", _muted_highlight_icon)
	else:
		remove_theme_icon_override("grabber")
		remove_theme_icon_override("grabber_highlight")
		if _saved_grabber_icon_override != null:
			add_theme_icon_override("grabber", _saved_grabber_icon_override)
		if _saved_grabber_highlight_icon_override != null:
			add_theme_icon_override("grabber_highlight", _saved_grabber_highlight_icon_override)

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
		"_mute_button_create":
			if is_instance_valid(mute_button):
				property.usage = PROPERTY_USAGE_NO_EDITOR

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

func _get_tooltip(at_position: Vector2) -> String:
	if not tooltip_display:
		return tooltip_text
	
	var parts : PackedStringArray = []
	
	if tooltip_show_bus_name:
		parts.append(bus_name.capitalize())
	
	if is_muted():
		parts.append("Muted")
	else:
		parts.append("%d%%" % roundi(value))
		if tooltip_show_decibels:
			parts.append("(%.1f dB)" % VolumeUtils.value_to_db(value))
	
	return " ".join(parts)


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
	match property:
		# Hides dynamically round_display_volume based on the state of rounded
		"rounded":
			notify_property_list_changed()
			_update_label_text.call_deferred()
		# "caches" the user set grabber icon override
		"theme_override_icons/grabber":
			_saved_grabber_icon_override = value if value != get_resolved_grabber_muted_icon() else null
		# same thing for grabber highlight
		"theme_override_icons/grabber_highlight":
			_saved_grabber_highlight_icon_override = value if value != get_resolved_grabber_muted_highlight_icon() else null
	return false

#endregion
