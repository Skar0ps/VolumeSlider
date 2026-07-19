## Utility functions shared by the volume slider addon: dB/linear conversion,
## bus lookup, volume persistence, and Inspector property list helpers.
extends RefCounted
class_name VolumeUtils

## Key used to store/retrieve the volume value inside the [ConfigFile].
const CONFIG_KEY := "volume_db"
## [ProjectSettings] path storing the [ConfigFile] location used for volume persistence.
const SETTING_PATH : String = "addons/volume_slider/config_path"
## Default [ConfigFile] path used when [constant SETTING_PATH] is unset.
const DEFAULT_PATH : String = "user://volume_slider.cfg"

## Linear slider value corresponding to 0 dB (unity gain).
const UNITY_GAIN_VALUE : float = 100.0
## [ProjectSettings] path for the minimum audible volume in decibels.
const MIN_DB_SETTING : String = "audio/buses/channel_disable_threshold_db"

#region Save 

## Returns the [ConfigFile] path from the [ProjectSettings] [member ProjectSettings.addons/volume_slider/config_path]
static func get_config_path() -> String:
	return ProjectSettings.get_setting(SETTING_PATH, DEFAULT_PATH)

## Sets the [ConfigFile] path in the [ProjectSettings] [member ProjectSettings.addons/volume_slider/config_path]
static func set_config_path(path: String) -> void:
	ProjectSettings.set_setting(SETTING_PATH, path)
	ProjectSettings.save()

## Loads the volume (in db) for the bus from the config file at the given [code]config_path[/code]
static func load_persisted_volume(bus_name: String, config_path: String) -> float:
	var bus_current_volume : float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))
	var config := ConfigFile.new()
	if config.load(config_path) == OK:
		return config.get_value(bus_name, CONFIG_KEY, bus_current_volume)
	return bus_current_volume

## Saves the volume (in db) for the bus to the config file at the given [code]config_path[/code]
static func save_persisted_volume(bus_name: String, config_path: String, volume_db: float) -> void:
	var config := ConfigFile.new()
	config.load(config_path)
	config.set_value(bus_name, CONFIG_KEY, volume_db)
	config.save(config_path)

#endregion

## Linear to decibels tweaked to the base range 0 to 100
static func value_to_db(value: float) -> float:
	if value <= 0.0:
		return -INF
	var linear_ratio : float = value / UNITY_GAIN_VALUE
	var db : float = linear_to_db(linear_ratio)
	return maxf(db, get_min_db())

## Decibels to linear tweaked to the base range 0 to 100
static func db_to_value(volume_db: float) -> float:
	if volume_db <= get_min_db():
		return 0.0
	return db_to_linear(volume_db) * UNITY_GAIN_VALUE

## Applies [param new_value] to the bus [param bus_name]: mutes it at [member Range.min_value],
## converts it to dB, and returns the resulting [param volume_db].
static func compute_bus_volume_db(bus_name: String, slider: Range, new_value: float) -> float:
	var bus_index : int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_error("No audio bus with name : " + bus_name)
		return NAN
	
	var was_muted : bool = AudioServer.is_bus_mute(bus_index)
	var should_mute : bool = new_value <= slider.min_value
	
	if not was_muted and should_mute:
		slider.muted.emit()
	if was_muted and not should_mute:
		slider.unmuted.emit()
	
	AudioServer.set_bus_mute(bus_index, should_mute)
	var volume_db : float = value_to_db(new_value)
	AudioServer.set_bus_volume_db(bus_index, volume_db)
	return volume_db

## Returns the [member ProjectSettings.audio/buses/channel_disable_threshold_db] value, defaulting to [code]-60.0[/code].
static func get_min_db() -> float:
	return ProjectSettings.get_setting(MIN_DB_SETTING, -60.0)

## Returns the [AudioBusLayout] bus name list.
static func get_bus_names() -> PackedStringArray:
	var names := PackedStringArray()
	for i in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(i))
	return names

## Returns the [AudioBusLayout] bus name list as an exported enum named [code]bus_name[/code].
static func get_bus_names_enum() -> Dictionary:
	var bus_names : PackedStringArray = get_bus_names()
	return {
		"name": "bus_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(bus_names),
		"usage": PROPERTY_USAGE_DEFAULT,
	}

## Returns the [ConfigFile] where the volume is saved, accessible in [member ProjectSettings.addons/volume_slider/config_path]
static func get_config_path_export() -> Dictionary:
	return {
		"name": "config_path",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_FILE,
		"hint_string": "*.cfg",
		"usage": PROPERTY_USAGE_EDITOR
	} 

static func get_tooltip_text(slider: Range, bus_name: String, tooltip_display: bool, show_bus_name: bool, show_decibels: bool, fallback_text: String) -> String:
	if not tooltip_display:
		return fallback_text
	var parts : PackedStringArray = []
	if show_bus_name:
		parts.append(bus_name.capitalize())
	if is_muted(slider, bus_name):
		parts.append("Muted")
	else:
		parts.append("%d%%" % roundi(slider.value))
		if show_decibels:
			parts.append("(%.1f dB)" % value_to_db(slider.value))
	return " ".join(parts)

static func get_resolved_grabber_muted_icon(slider: Slider, override_icon: Texture2D) -> Texture2D:
	if override_icon != null:
		return override_icon
	var custom_type : StringName = slider.get_script().get_global_name()
	if slider.has_theme_icon(&"grabber_muted", custom_type):
		return slider.get_theme_icon(&"grabber_muted", custom_type)
	if slider.has_theme_icon(&"grabber", slider.get_class()):
		return slider.get_theme_icon(&"grabber", slider.get_class())
	return null

static func get_resolved_grabber_muted_highlight_icon(slider: Slider, override_icon: Texture2D, fallback_muted_icon: Texture2D) -> Texture2D:
	if override_icon != null:
		return override_icon
	var custom_type : StringName = slider.get_script().get_global_name()
	if slider.has_theme_icon(&"grabber_muted_highlight", custom_type):
		return slider.get_theme_icon(&"grabber_muted_highlight", custom_type)
	if slider.has_theme_icon(&"grabber_highlight", slider.get_class()):
		return slider.get_theme_icon(&"grabber_highlight", slider.get_class())
	return fallback_muted_icon

## Returns [code]true[/code] if the given bus name exists
static func is_valid_bus(bus_name:String) -> bool:
	return AudioServer.get_bus_index(bus_name) != -1

static func is_muted(slider: Range, bus_name: String) -> bool:
	if not is_valid_bus(bus_name):
		return false
	var bus_index : int = AudioServer.get_bus_index(bus_name)
	var is_bus_mute : bool = AudioServer.is_bus_mute(bus_index)
	if Engine.is_editor_hint():
		return slider.value <= slider.min_value or is_bus_mute
	return is_bus_mute

## Synchronises the slider to the corresponding bus volume
static func sync_slider_with_bus(slider: Range, bus_name: String, save_volume: bool, config_path: String) -> void:
	var bus_index : int = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		var volume_db : float = AudioServer.get_bus_volume_db(bus_index)
		if save_volume:
			volume_db = load_persisted_volume(bus_name, config_path)
		slider.value = db_to_value(volume_db)

## Creates a [CheckBox] mute button next to [param slider], reparenting it into a
## [VBoxContainer] if it's a [VVolumeSlider] or a [HBoxContainer] if it's a [HVolumeSlider] if its parent isn't already one.[br]
static func create_mute_button(slider: Slider, bus_name: String) -> void:
	if not Engine.is_editor_hint():
		return
	if not slider.is_inside_tree() or slider.get_parent() == null:
		push_warning("Cannot create mute button: node is not inside the tree yet.")
		return
	if not slider is VVolumeSlider and not slider is HVolumeSlider:
		return
	if is_instance_valid(slider.mute_button):
		return
	
	var bus_index : int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_error("No audio bus with name: " + bus_name)
		return
	
	var parent : Node = slider.get_parent()
	var container : BoxContainer
	
	if parent is VBoxContainer and slider is VVolumeSlider:
		container = parent
	elif parent is HBoxContainer and slider is HVolumeSlider:
		container = parent
	else:
		container = VBoxContainer.new() if slider is VVolumeSlider else HBoxContainer.new()
		container.size_flags_horizontal = slider.size_flags_horizontal
		container.size_flags_vertical = slider.size_flags_vertical
		container.size_flags_stretch_ratio = slider.size_flags_stretch_ratio
		parent.add_child(container, true)
		container.owner = slider.owner
		slider.reparent(container)
	
	var mute_button := CheckBox.new()
	mute_button.name = bus_name.capitalize() + "MuteButton"
	mute_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mute_button.button_pressed = AudioServer.is_bus_mute(bus_index)
	container.add_child(mute_button, true)
	container.move_child(mute_button, slider.get_index())
	mute_button.set_owner(slider.owner)
	
	var checked_icon : Texture2D
	var unchecked_icon : Texture2D
	if is_instance_valid(EditorInterface.get_editor_theme()):
		var editor_theme : Theme = EditorInterface.get_editor_theme()
		if editor_theme.has_icon(&"AudioMute", &"EditorIcons"):
			checked_icon = editor_theme.get_icon(&"AudioMute", &"EditorIcons")
		if editor_theme.has_icon(&"AudioStreamPlayer", &"EditorIcons"):
			unchecked_icon = editor_theme.get_icon(&"AudioStreamPlayer", &"EditorIcons")
	
	if is_instance_valid(checked_icon):
		mute_button.add_theme_icon_override(&"checked", checked_icon)
	if is_instance_valid(unchecked_icon):
		mute_button.add_theme_icon_override(&"unchecked", unchecked_icon)
	
	if is_instance_valid(mute_button):
		slider.mute_button = mute_button
		mute_button.tree_exited.connect(slider._on_mute_button_tree_exited)
		mute_button.toggled.connect(slider._on_mute_button_toggled)

static func update_grabber_icon(slider: Slider, bus_name: String, muted_icon: Texture2D, muted_highlight_icon: Texture2D, saved_icon: Texture2D, saved_highlight_icon: Texture2D) -> void:
	if not is_valid_bus(bus_name):
		return
	if muted_icon == null:
		push_error("No muted icon has been set")
		return
	if is_muted(slider, bus_name):
		slider.add_theme_icon_override("grabber", muted_icon)
		slider.add_theme_icon_override("grabber_highlight", muted_highlight_icon)
	else:
		slider.remove_theme_icon_override("grabber")
		slider.remove_theme_icon_override("grabber_highlight")
		if saved_icon != null:
			slider.add_theme_icon_override("grabber", saved_icon)
		if saved_highlight_icon != null:
			slider.add_theme_icon_override("grabber_highlight", saved_highlight_icon)

static func update_label_text(slider: Range, display_label: Label, label_display: bool, update_in_editor: bool, round_display_volume: bool) -> void:
	if Engine.is_editor_hint() and not update_in_editor:
		return
	if not label_display or not is_instance_valid(display_label):
		return
	var displayed_value : String = str(round_display_volume) if false else str(slider.value)
	if round_display_volume:
		displayed_value = str(roundi(slider.value))
	display_label.text = displayed_value
