## A horizontal slider that controls the volume of an audio bus.
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
signal volume_changed(volume_db: float)

## Emitted when the slider mutes.
## This happens when the slider is set to its minimum value.
signal muted()

## Emitted when the slider unmutes.
## This happens when the slider is set to a non-minimum value.
signal unmuted()

## The name of the audio bus to control.
## This list is populated dynamically from the project's audio bus layout.
##[br][member ProjectSettings.audio/buses/default_bus_layout].
var bus_name: String = "Master":
	set = set_bus_name

@export_group("Label Display")

## (Optional) Label node used to display the volume.
@export var display_label: Label:
	set = set_display_label

## Creates a [Label] that will display this slider's volume
@export_tool_button("Create a volume label", "Label") var _label_create: Callable:
	get ():
		return VolumeUtils.create_label.bind(self, bus_name)

## If [code]true[/code], rounds the displayed volume to the nearest integer.
##[br]Ignored if [member rounded] is [code]true[/code] or no [member display_label] is set.
@export var round_display_volume: bool = true:
	set(new_value):
		round_display_volume = new_value
		update_label_text()
	get:
		if not rounded:
			return round_display_volume
		return rounded

## If [code]true[/code], updates the label to the volume even when inside the editor.
##[br]Ignored if no [member display_label] is set.
@export var update_label_in_editor: bool = false:
	set(new_value):
		update_label_in_editor = new_value
		update_label_text()

@export_group("Mute Button")

## (Optional) Synchronize a mute button with this VolumeSlider.
@export var mute_button: Button:
	set(new_button):
		mute_button = new_button
		VolumeUtils.check_mute_button_signals(self, bus_name)
		notify_property_list_changed()

## Creates a [CheckBox] that will toggle the mute state of this slider volume.
@export_tool_button("Create a mute button", "AudioMute") var _mute_button_create: Callable:
	get ():
		return VolumeUtils.create_mute_button.bind(self, bus_name)

@export_group("Tooltip Display", "tooltip_")
## If [code]true[/code], displays a tooltip showing the current volume when hovering the slider.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var tooltip_display: bool = false

## If [code]true[/code], includes the volume in decibels in the tooltip.
@export var tooltip_show_decibels: bool = false

## If [code]true[/code], includes the audio bus name in the tooltip.
@export var tooltip_show_bus_name: bool = false

## Preview of the tooltip shown when hovering the slider.
@export_custom(PROPERTY_HINT_TYPE_STRING, "", PROPERTY_USAGE_EDITOR + PROPERTY_USAGE_READ_ONLY) var tooltip_preview: String:
	get ():
		return _get_tooltip(Vector2.ZERO)

@export_group("Editor")

## If [code]true[/code], allows the slider to affect the bus volume in the editor when changed.[br][br]
## [b]Note :[/b] It is recommended to not keep this to [code]true[/code] and only turn it on while debugging the VolumeSlider,
## as the bus volume will not be reset when starting the game.
@export var modify_bus_volume_in_editor: bool = false


## Icon used for the grabber when the slider's bus is muted.
## Returns null if unset, use [method get_resolved_grabber_muted_icon] for display purposes.
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "Texture2D", PROPERTY_USAGE_STORAGE) var grabber_muted_icon: Texture2D:
	set(new_icon):
		grabber_muted_icon = new_icon
		update_grabber_icon()

## Grabber icon override "cache" to prevent grabber_muted from discarding the user set grabber icon override.
var _saved_grabber_icon_override: Texture2D = null

## Icon used for the grabber_highlight when the slider's bus is muted.
## Returns null if unset, use [method get_resolved_grabber_muted_highlight_icon] for display purposes.
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "Texture2D", PROPERTY_USAGE_STORAGE) var grabber_muted_highlight_icon: Texture2D:
	set(new_icon):
		grabber_muted_highlight_icon = new_icon
		update_grabber_icon()

## Grabber highlight icon override "cache" to prevent grabber_muted_highlight from discarding the user set override.
var _saved_grabber_highlight_icon_override: Texture2D = null


## Initializes the slider's value to full volume (100) by default.
func _init() -> void:
	value = 100.0


## Delegates all shared ready-time setup to [method VolumeUtils.setup_slider_ready].
func _ready() -> void:
	VolumeUtils.setup_slider_ready(self, bus_name)

#region Helpers

## Clears [member display_label] when the assigned [Label] leaves the tree.
func _on_display_label_tree_exited() -> void:
	VolumeUtils.on_display_label_tree_exited(self)


## Clears [member mute_button] when the assigned button leaves the tree.
func _on_mute_button_tree_exited() -> void:
	VolumeUtils.on_mute_button_tree_exited(self)


## Applies the [member mute_button]'s toggled state to the [AudioServer] bus.
func _on_mute_button_toggled(is_muted_now: bool) -> void:
	VolumeUtils.on_mute_button_toggled(self, bus_name, is_muted_now)


## Returns [code]true[/code] if the slider's bus is currently muted.
func is_muted() -> bool:
	return VolumeUtils.is_muted(self, bus_name)


## Returns the icon actually used for the grabber when muted, resolving theme fallbacks if unset.
func get_resolved_grabber_muted_icon() -> Texture2D:
	return VolumeUtils.get_resolved_grabber_muted_icon(self, grabber_muted_icon)


## Returns the icon actually used for grabber_highlight when muted, resolving theme fallbacks if unset.
func get_resolved_grabber_muted_highlight_icon() -> Texture2D:
	return VolumeUtils.get_resolved_grabber_muted_highlight_icon(
			self,
			grabber_muted_highlight_icon,
			get_resolved_grabber_muted_icon(),
	)

#endregion

## Called when the slider's value is changed by the user. Delegates to [method VolumeUtils.handle_value_changed].
func _value_changed(new_value: float) -> void:
	VolumeUtils.handle_value_changed(self, bus_name, new_value, modify_bus_volume_in_editor)


## Updates the [member display_label] text if the conditions are met
func update_label_text() -> void:
	VolumeUtils.update_label_text(
			self,
			display_label,
			update_label_in_editor,
			round_display_volume or rounded,
	)


## Refreshes the grabber/grabber_highlight theme icon overrides based on the current muted state.
func update_grabber_icon() -> void:
	VolumeUtils.update_grabber_icon(
			self,
			bus_name,
			get_resolved_grabber_muted_icon(),
			get_resolved_grabber_muted_highlight_icon(),
			_saved_grabber_icon_override,
			_saved_grabber_highlight_icon_override,
	)


## Hides irrelevant Inspector properties and toggles read-only states dynamically.
func _validate_property(property: Dictionary) -> void:
	VolumeUtils.validate_slider_property(self, property)


## Used for displaying the dynamic dropdown of bus names in the inspector
func _get_property_list() -> Array[Dictionary]:
	return VolumeUtils.build_slider_property_list()


## Returns the tooltip text to display when hovering the slider.
func _get_tooltip(_at_position: Vector2) -> String:
	return VolumeUtils.get_tooltip_text(
			self,
			bus_name,
			tooltip_display,
			tooltip_show_bus_name,
			tooltip_show_decibels,
			tooltip_text,
	)

#region Setters

## Sets [member bus_name] after validating it exists, then resynchronizes the slider.
func set_bus_name(new_bus_name: String) -> void:
	bus_name = VolumeUtils.set_slider_bus_name(self, new_bus_name)


## Sets [member display_label] and immediately refreshes its displayed text.
func set_display_label(new_label: Label) -> void:
	display_label = new_label
	VolumeUtils.set_slider_display_label(self, display_label)


## Hides [member round_display_volume] dynamically and caches user-set grabber icon overrides.
func _set(property: StringName, value: Variant) -> bool:
	VolumeUtils.handle_set(self, property, value)
	return false

#endregion
