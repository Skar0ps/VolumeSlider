## Utility functions shared by the volume slider addon: dB/linear conversion,
## bus lookup, volume persistence, dynamic node creation (mute button/label),
## and Inspector property list helpers.
extends RefCounted

class_name VolumeUtils

## Key used to store/retrieve the volume value inside the [ConfigFile].
const CONFIG_KEY := "volume_db"
## [ProjectSettings] path storing the [ConfigFile] location used for volume persistence.
const SETTING_PATH: String = "addons/volume_slider/config_path"
## Default [ConfigFile] path used when [constant SETTING_PATH] is unset.
const DEFAULT_PATH: String = "user://volume_slider.cfg"

## Linear slider value corresponding to 0 dB (unity gain).
const UNITY_GAIN_VALUE: float = 100.0
## [ProjectSettings] path for the minimum audible volume in decibels.
const MIN_DB_SETTING: String = "audio/buses/channel_disable_threshold_db"
## Layout mode value meaning "anchored inside a container" for [Control] nodes.
const _LAYOUT_MODE_CONTAINER: int = 2

#region Volume Persistence

## Returns the [ConfigFile] path from the [ProjectSettings] [member ProjectSettings.addons/volume_slider/config_path]
static func get_config_path() -> String:
	return ProjectSettings.get_setting(SETTING_PATH, DEFAULT_PATH)


## Sets the [ConfigFile] path in the [ProjectSettings] [member ProjectSettings.addons/volume_slider/config_path]
static func set_config_path(path: String) -> void:
	ProjectSettings.set_setting(SETTING_PATH, path)
	ProjectSettings.save()


## Loads the volume (in db) for the bus from the config file at the given [code]config_path[/code]
static func load_persisted_volume(bus_name: String, config_path: String = get_config_path()) -> float:
	var bus_current_volume: float = AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index(bus_name)
	)
	var config := ConfigFile.new()
	if config.load(config_path) == OK:
		return config.get_value(bus_name, CONFIG_KEY, bus_current_volume)
	return bus_current_volume


## Saves the volume (in db) for the bus to the config file at the given [code]config_path[/code]
static func save_persisted_volume(
		bus_name: String,
		volume_db: float,
		config_path: String = get_config_path(),
) -> void:
	var config := ConfigFile.new()
	config.load(config_path)
	config.set_value(bus_name, CONFIG_KEY, volume_db)
	config.save(config_path)


## Returns [code]true[/code] if the [ConfigFile] at [param config_path] has at least one persisted bus volume.
static func has_persisted_volumes(config_path: String = get_config_path()) -> bool:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return false
	return not config.get_sections().is_empty()

#endregion

#region dB / Linear Conversion

## Linear to decibels tweaked to the base range 0 to 100
static func value_to_db(value: float) -> float:
	if value <= 0.0:
		return -INF
	var linear_ratio: float = value / UNITY_GAIN_VALUE
	var db: float = linear_to_db(linear_ratio)
	return maxf(db, get_min_db())


## Decibels to linear tweaked to the base range 0 to 100
static func db_to_value(volume_db: float) -> float:
	if volume_db <= get_min_db():
		return 0.0
	return db_to_linear(volume_db) * UNITY_GAIN_VALUE


## Returns the [member ProjectSettings.audio/buses/channel_disable_threshold_db] value, defaulting to [code]-60.0[/code].
static func get_min_db() -> float:
	return ProjectSettings.get_setting(MIN_DB_SETTING, -60.0)

#endregion

#region Bus Lookup & Info

## Returns the [AudioBusLayout] bus name list.
static func get_bus_names() -> PackedStringArray:
	var names := PackedStringArray()
	for i in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(i))
	return names


## Returns the [AudioBusLayout] bus name list as an exported enum named [code]bus_name[/code].
static func get_bus_names_enum() -> Dictionary:
	var bus_names: PackedStringArray = get_bus_names()
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
		"usage": PROPERTY_USAGE_EDITOR,
	}


## Returns [code]true[/code] if the given bus name exists
static func is_valid_bus(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) != -1


## Returns [code]true[/code] if [param slider]'s bus is currently muted, either through
## the [AudioServer] directly or, inside the editor, because the slider is at its minimum value.
static func is_muted(slider: Range, bus_name: String) -> bool:
	if not is_valid_bus(bus_name):
		return false
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	var is_bus_mute: bool = AudioServer.is_bus_mute(bus_index)
	if Engine.is_editor_hint():
		return slider.value <= slider.min_value or is_bus_mute
	return is_bus_mute

#endregion

#region Slider Sync & Display

## Applies [param new_value] to the bus [param bus_name]: mutes it at [member Range.min_value],
## converts it to dB, and returns the resulting [param volume_db].
static func compute_bus_volume_db(bus_name: String, slider: Range, new_value: float) -> float:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_error("No audio bus with name : " + bus_name)
		return NAN

	var was_muted: bool = AudioServer.is_bus_mute(bus_index)
	var should_mute: bool = new_value <= slider.min_value

	if not was_muted and should_mute:
		slider.muted.emit()
	if was_muted and not should_mute:
		slider.unmuted.emit()

	AudioServer.set_bus_mute(bus_index, should_mute)
	var volume_db: float = value_to_db(new_value)
	AudioServer.set_bus_volume_db(bus_index, volume_db)
	return volume_db


## Synchronises the slider to the corresponding bus volume, and applies the
## persisted volume to the [AudioServer] bus itself if [param save_volume] is enabled,
## so the bus is corrected even if this is the first slider referencing it.
static func sync_slider_with_bus(
		slider: Range,
		bus_name: String,
		save_volume: bool,
		config_path: String = get_config_path(),
) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_error(
				"Cannot sync slider %s: the bus_name '%s' is invalid." % [
					slider.get_path(),
					bus_name,
				]
		)
		return

	var volume_db: float = AudioServer.get_bus_volume_db(bus_index)
	if save_volume:
		volume_db = load_persisted_volume(bus_name, config_path)
		AudioServer.set_bus_volume_db(bus_index, volume_db)

	var target_value: float = db_to_value(volume_db)
	slider.set_value_no_signal(target_value)

	var check_slider_value: Callable = func():
		if not is_equal_approx(target_value, slider.value):
			push_error("Slider value was not synced with bus volume for %s." % slider.get_path())
	check_slider_value.call_deferred()


## Builds the tooltip text shown when hovering the slider, combining the bus
## name, mute state, and/or volume percentage/decibels depending on the flags.
static func get_tooltip_text(
		slider: Range,
		bus_name: String,
		tooltip_display: bool,
		show_bus_name: bool,
		show_decibels: bool,
		fallback_text: String,
) -> String:
	if not tooltip_display:
		return fallback_text
	var parts: PackedStringArray = []
	if show_bus_name:
		parts.append(bus_name.capitalize())
	if is_muted(slider, bus_name):
		parts.append("Muted")
	else:
		parts.append("%d%%" % roundi(slider.value))
		if show_decibels:
			parts.append("(%.1f dB)" % value_to_db(slider.value))
	return " ".join(parts)


## Returns the icon to use for the grabber when muted: the explicit
## [param override_icon] if set, otherwise a theme icon fallback resolved
## from the slider's custom type, then its base class.
static func get_resolved_grabber_muted_icon(slider: Slider, override_icon: Texture2D) -> Texture2D:
	if override_icon != null:
		return override_icon
	var custom_type: StringName = slider.get_script().get_global_name()
	if slider.has_theme_icon(&"grabber_muted", custom_type):
		return slider.get_theme_icon(&"grabber_muted", custom_type)
	if slider.has_theme_icon(&"grabber", slider.get_class()):
		return slider.get_theme_icon(&"grabber", slider.get_class())
	return null


## Same resolution logic as [method get_resolved_grabber_muted_icon], but for
## the highlighted grabber variant, falling back to [param fallback_muted_icon] if unset.
static func get_resolved_grabber_muted_highlight_icon(
		slider: Slider,
		override_icon: Texture2D,
		fallback_muted_icon: Texture2D,
) -> Texture2D:
	if override_icon != null:
		return override_icon
	var custom_type: StringName = slider.get_script().get_global_name()
	if slider.has_theme_icon(&"grabber_muted_highlight", custom_type):
		return slider.get_theme_icon(&"grabber_muted_highlight", custom_type)
	if slider.has_theme_icon(&"grabber_highlight", slider.get_class()):
		return slider.get_theme_icon(&"grabber_highlight", slider.get_class())
	return fallback_muted_icon


## Applies or clears the muted grabber/grabber_highlight theme icon overrides
## on [param slider] depending on its current muted state, restoring any
## user-set override ([param saved_icon]/[param saved_highlight_icon]) once unmuted.
static func update_grabber_icon(
		slider: Slider,
		bus_name: String,
		muted_icon: Texture2D,
		muted_highlight_icon: Texture2D,
		saved_icon: Texture2D,
		saved_highlight_icon: Texture2D,
) -> void:
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


## Refreshes [param display_label]'s text with the slider's current value,
## respecting [param label_display], [param update_in_editor], and rounding settings.
static func update_label_text(
		slider: Range,
		display_label: Label,
		label_display: bool,
		update_in_editor: bool,
		round_display_volume: bool,
) -> void:
	if Engine.is_editor_hint() and not update_in_editor:
		return
	if not label_display or not is_instance_valid(display_label):
		return
	var displayed_value: String = str(slider.value)
	if round_display_volume:
		displayed_value = str(roundi(slider.value))
	display_label.text = displayed_value

#endregion

#region Container & Rect Helpers

## Returns [code]true[/code] if [param slider] needs to be reparented into a new
## VBoxContainer/HBoxContainer, i.e. its current parent isn't already
## the matching box container type.
static func _needs_new_container(slider: Slider, parent: Node) -> bool:
	return not ((parent is VBoxContainer and slider is VVolumeSlider)
	or (parent is HBoxContainer and slider is HVolumeSlider))


## Snapshots the full rect definition (anchors + offsets + size flags) of a
## Control. Used to restore it exactly on undo, without ever touching
## .size/.position directly (see control.cpp _set_size() warning).
static func _snapshot_control_rect(control: Control) -> Dictionary:
	return {
		"anchor_left": control.anchor_left,
		"anchor_top": control.anchor_top,
		"anchor_right": control.anchor_right,
		"anchor_bottom": control.anchor_bottom,
		"offset_left": control.offset_left,
		"offset_top": control.offset_top,
		"offset_right": control.offset_right,
		"offset_bottom": control.offset_bottom,
		"custom_minimum_size": control.custom_minimum_size,
		"size_flags_horizontal": control.size_flags_horizontal,
		"size_flags_vertical": control.size_flags_vertical,
	}


## Restores a Control's rect from a snapshot taken by [method _snapshot_control_rect].
static func _restore_control_rect(control: Control, snapshot: Dictionary) -> void:
	control.size_flags_horizontal = snapshot.size_flags_horizontal
	control.size_flags_vertical = snapshot.size_flags_vertical
	control.custom_minimum_size = snapshot.custom_minimum_size
	control.anchor_left = snapshot.anchor_left
	control.anchor_top = snapshot.anchor_top
	control.anchor_right = snapshot.anchor_right
	control.anchor_bottom = snapshot.anchor_bottom
	control.offset_left = snapshot.offset_left
	control.offset_top = snapshot.offset_top
	control.offset_right = snapshot.offset_right
	control.offset_bottom = snapshot.offset_bottom


## Applies a slider's rect snapshot to a newly created container, so the
## container occupies exactly the same space the slider used to.
static func _apply_rect_to_container(container: Control, slider: Slider, snapshot: Dictionary) -> void:
	container.layout_mode = slider.layout_mode
	container.anchor_left = snapshot.anchor_left
	container.anchor_top = snapshot.anchor_top
	container.anchor_right = snapshot.anchor_right
	container.anchor_bottom = snapshot.anchor_bottom
	container.offset_left = snapshot.offset_left
	container.offset_top = snapshot.offset_top
	container.offset_right = snapshot.offset_right
	container.offset_bottom = snapshot.offset_bottom
	container.grow_horizontal = slider.grow_horizontal
	container.grow_vertical = slider.grow_vertical


## Grows the container's minimum size to fit its content. Only touches
## custom_minimum_size, never .size directly, since Control automatically
## clamps its actual size to the combined minimum on the next layout pass
## regardless of anchor configuration — this is the only warning-free way
## to influence size on a Control with arbitrary/non-equal anchors.
static func _fit_container_to_content(container: Control) -> void:
	if not is_instance_valid(container):
		return
	var min_size: Vector2 = container.get_combined_minimum_size()
	container.custom_minimum_size = container.custom_minimum_size.max(min_size)


## Applies the shrink-on-cross-axis flag to a secondary control (mute button,
## label...) added next to the slider, so it stays at its natural size on the
## axis perpendicular to the box container's stacking direction.
static func _shrink_on_cross_axis(control: Control, slider: Slider) -> void:
	if slider is VVolumeSlider:
		control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER

#endregion

#region Mute Button Creation

## Creates a [CheckBox] mute button next to [param slider], reparenting it into a
## [VBoxContainer]/[HBoxContainer] if its parent isn't already one.
## The whole operation is registered as a single undoable editor action.
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

	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_error("No audio bus with name: " + bus_name)
		return

	# Defer the whole action so it runs AFTER the inspector button's
	# signal emission has fully unwound, avoiding the "freed while a
	# signal is being emitted" error.
	_create_mute_button_deferred.call_deferred(slider, bus_name, bus_index)


## Builds the [CheckBox], its container (if needed), and registers the whole
## creation as a single [EditorUndoRedoManager] action.
static func _create_mute_button_deferred(slider: Slider, bus_name: String, bus_index: int) -> void:
	if not is_instance_valid(slider) or is_instance_valid(slider.mute_button):
		return

	var parent: Node = slider.get_parent()
	var needs_new_container: bool = _needs_new_container(slider, parent)
	var slider_snapshot: Dictionary = _snapshot_control_rect(slider)

	var container: Control = parent
	if needs_new_container:
		container = VBoxContainer.new() if slider is VVolumeSlider else HBoxContainer.new()
		container.name = bus_name.capitalize() + "VolumeContainer"
		_apply_rect_to_container(container, slider, slider_snapshot)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var mute_button := CheckBox.new()
	mute_button.name = bus_name.capitalize() + "MuteButton"
	mute_button.button_pressed = AudioServer.is_bus_mute(bus_index)
	_shrink_on_cross_axis(mute_button, slider)

	if is_instance_valid(EditorInterface.get_editor_theme()):
		var editor_theme: Theme = EditorInterface.get_editor_theme()
		if editor_theme.has_icon(&"AudioMute", &"EditorIcons"):
			mute_button.add_theme_icon_override(
					&"checked",
					editor_theme.get_icon(&"AudioMute", &"EditorIcons"),
			)
		if editor_theme.has_icon(&"AudioStreamPlayer", &"EditorIcons"):
			mute_button.add_theme_icon_override(
					&"unchecked",
					editor_theme.get_icon(&"AudioStreamPlayer", &"EditorIcons"),
			)

	var owner: Node = slider.owner
	var original_index: int = slider.get_index()

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Create Mute Button", UndoRedo.MERGE_DISABLE, slider)
	undo_redo.add_do_method(
			VolumeUtils,
			"_do_create_mute_button",
			slider,
			parent,
			container,
			mute_button,
			needs_new_container,
			owner,
	)
	undo_redo.add_undo_method(
			VolumeUtils,
			"_undo_create_mute_button",
			slider,
			parent,
			container,
			mute_button,
			needs_new_container,
			original_index,
			owner,
			slider_snapshot,
	)
	undo_redo.add_do_reference(mute_button)
	if needs_new_container:
		undo_redo.add_do_reference(container)
	undo_redo.commit_action()

	if needs_new_container:
		_fit_container_to_content.call_deferred(container)


## "do" operation of [method create_mute_button] for the editor UndoRedo.
static func _do_create_mute_button(
		slider: Slider,
		parent: Node,
		container: BoxContainer,
		mute_button: CheckBox,
		needs_new_container: bool,
		owner: Node,
) -> void:
	if needs_new_container:
		parent.add_child(container, true)
		container.owner = owner
		parent.remove_child(slider)
		container.add_child(slider)
		slider.owner = owner
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_EXPAND_FILL

	container.add_child(mute_button, true)
	container.move_child(mute_button, slider.get_index())
	mute_button.owner = owner

	slider.mute_button = mute_button
	if not mute_button.tree_exited.is_connected(slider._on_mute_button_tree_exited):
		mute_button.tree_exited.connect(slider._on_mute_button_tree_exited)
	if not mute_button.toggled.is_connected(slider._on_mute_button_toggled):
		mute_button.toggled.connect(slider._on_mute_button_toggled)


## "undo" operation of [method create_mute_button] for the editor UndoRedo.
## Restores the slider's exact original rect via anchors + offsets, never
## via .size/.position, to avoid fighting Control's internal anchor-driven
## size computation (see warning in control.cpp _set_size()).
static func _undo_create_mute_button(
		slider: Slider,
		parent: Node,
		container: BoxContainer,
		mute_button: CheckBox,
		needs_new_container: bool,
		original_index: int,
		owner: Node,
		slider_snapshot: Dictionary,
) -> void:
	if mute_button.toggled.is_connected(slider._on_mute_button_toggled):
		mute_button.toggled.disconnect(slider._on_mute_button_toggled)
	if mute_button.tree_exited.is_connected(slider._on_mute_button_tree_exited):
		mute_button.tree_exited.disconnect(slider._on_mute_button_tree_exited)
	slider.mute_button = null
	container.remove_child(mute_button)

	if needs_new_container:
		container.remove_child(slider)
		parent.add_child(slider)
		parent.move_child(slider, original_index)
		slider.owner = owner
		parent.remove_child(container)
		_restore_control_rect(slider, slider_snapshot)

#endregion

#region Volume Label Creation

## Creates a [Label] next to [param slider], reparenting it into a
## [VBoxContainer]/[HBoxContainer] if its parent isn't already one.
## The whole operation is registered as a single undoable editor action.
static func create_label(slider: Range, bus_name: String) -> void:
	if not Engine.is_editor_hint():
		return
	if not slider.is_inside_tree() or slider.get_parent() == null:
		push_warning("Cannot create label: node is not inside the tree yet.")
		return
	if not slider is VVolumeSlider and not slider is HVolumeSlider:
		return
	if is_instance_valid(slider.display_label):
		return

	_create_label_deferred.call_deferred(slider, bus_name)


## Builds the [Label], its container (if needed), and registers the whole
## creation as a single [EditorUndoRedoManager] action.
static func _create_label_deferred(slider: Range, bus_name: String) -> void:
	if not is_instance_valid(slider) or is_instance_valid(slider.display_label):
		return

	var parent: Node = slider.get_parent()
	var needs_new_container: bool = _needs_new_container(slider, parent)
	var slider_snapshot: Dictionary = _snapshot_control_rect(slider)

	var container: Control = parent
	if needs_new_container:
		container = VBoxContainer.new() if slider is VVolumeSlider else HBoxContainer.new()
		container.name = bus_name.capitalize() + "VolumeContainer"
		_apply_rect_to_container(container, slider, slider_snapshot)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var display_label := Label.new()
	display_label.name = bus_name.capitalize() + "VolumeLabel"
	display_label.text = str(roundi(slider.value))
	_shrink_on_cross_axis(display_label, slider)

	var owner: Node = slider.owner
	var original_index: int = slider.get_index()

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Create Volume Label", UndoRedo.MERGE_DISABLE, slider)
	undo_redo.add_do_method(
			VolumeUtils,
			"_do_create_label",
			slider,
			parent,
			container,
			display_label,
			needs_new_container,
			owner,
	)
	undo_redo.add_undo_method(
			VolumeUtils,
			"_undo_create_label",
			slider,
			parent,
			container,
			display_label,
			needs_new_container,
			original_index,
			owner,
			slider_snapshot,
	)
	undo_redo.add_do_reference(display_label)
	if needs_new_container:
		undo_redo.add_do_reference(container)
	undo_redo.commit_action()

	if needs_new_container:
		_fit_container_to_content.call_deferred(container)


## "do" operation of [method create_label] for the editor UndoRedo.
static func _do_create_label(
		slider: Range,
		parent: Node,
		container: BoxContainer,
		display_label: Label,
		needs_new_container: bool,
		owner: Node,
) -> void:
	if needs_new_container:
		parent.add_child(container, true)
		container.owner = owner
		parent.remove_child(slider)
		container.add_child(slider)
		slider.owner = owner
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_EXPAND_FILL

	container.add_child(display_label, true)
	container.move_child(display_label, slider.get_index() + 1)
	display_label.owner = owner

	slider.display_label = display_label
	slider.label_display = true
	if not display_label.tree_exited.is_connected(slider._on_display_label_tree_exited):
		display_label.tree_exited.connect(slider._on_display_label_tree_exited)


## "undo" operation of [method create_label] for the editor UndoRedo.
static func _undo_create_label(
		slider: Range,
		parent: Node,
		container: BoxContainer,
		display_label: Label,
		needs_new_container: bool,
		original_index: int,
		owner: Node,
		slider_snapshot: Dictionary,
) -> void:
	if display_label.tree_exited.is_connected(slider._on_display_label_tree_exited):
		display_label.tree_exited.disconnect(slider._on_display_label_tree_exited)
	slider.display_label = null
	slider.label_display = false
	container.remove_child(display_label)

	if needs_new_container:
		container.remove_child(slider)
		parent.add_child(slider)
		parent.move_child(slider, original_index)
		slider.owner = owner
		parent.remove_child(container)
		_restore_control_rect(slider, slider_snapshot)

#endregion

#region Shared Slider Lifecycle

## Performs all [code]_ready()[/code] setup shared by both slider orientations:
## editor bus-layout listeners, drag_ended connection, bus synchronization,
## default accessibility strings, and optional [member mute_button] wiring.
static func setup_slider_ready(slider: Slider, bus_name: String, save_volume: bool) -> void:
	if Engine.is_editor_hint():
		if not AudioServer.bus_layout_changed.is_connected(slider.notify_property_list_changed):
			AudioServer.bus_layout_changed.connect(slider.notify_property_list_changed)
		if not AudioServer.bus_renamed.is_connected(slider._on_bus_renamed):
			AudioServer.bus_renamed.connect(slider._on_bus_renamed)
	slider._check_drag_ended_connection()
	sync_slider_with_bus(slider, bus_name, save_volume)

	if slider.accessibility_name.is_empty():
		slider.accessibility_name = "%s Volume Slider" % bus_name.capitalize()
	if slider.accessibility_description.is_empty():
		slider.accessibility_description = "Adjusts the %s audio bus volume, currently %.0f percent" % [
			bus_name,
			slider.value,
		]

	slider.mouse_exited.connect(slider.release_focus)
	if is_instance_valid(slider.mute_button):
		if not slider.mute_button.toggled.is_connected(slider._on_mute_button_toggled):
			slider.mute_button.toggled.connect(slider._on_mute_button_toggled)
		if not slider.mute_button.tree_exited.is_connected(slider._on_mute_button_tree_exited):
			slider.mute_button.tree_exited.connect(slider._on_mute_button_tree_exited)
		slider.muted.connect(slider.mute_button.set_pressed_no_signal.bind(true))
		slider.unmuted.connect(slider.mute_button.set_pressed_no_signal.bind(false))


## Connects or disconnects the [signal Range.drag_ended] signal based on [param save_on_drag_end].
static func check_drag_ended_connection(slider: Slider, save_on_drag_end: bool) -> void:
	if save_on_drag_end:
		if not slider.drag_ended.is_connected(slider._on_drag_ended):
			slider.drag_ended.connect(slider._on_drag_ended)
	elif slider.drag_ended.is_connected(slider._on_drag_ended):
		slider.drag_ended.disconnect(slider._on_drag_ended)


## Clears [member display_label] when the assigned [Label] leaves the tree,
## and refreshes the Inspector so the "Create a volume label" button reappears.
static func on_display_label_tree_exited(slider: Slider) -> void:
	slider.display_label = null
	if Engine.is_editor_hint():
		slider.notify_property_list_changed()


## Clears [member mute_button] when the assigned button leaves the tree,
## and refreshes the Inspector so the "Create a mute button" button reappears.
static func on_mute_button_tree_exited(slider: Slider) -> void:
	slider.mute_button = null
	if Engine.is_editor_hint():
		slider.notify_property_list_changed()


## Applies the [member mute_button]'s toggled state to the [AudioServer] bus,
## and refreshes the grabber icon to reflect the new muted state.
static func on_mute_button_toggled(slider: Slider, bus_name: String, is_muted_now: bool) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_error("No audio bus with name: " + bus_name)
		return
	AudioServer.set_bus_mute(bus_index, is_muted_now)
	slider._update_grabber_icon()


## Handles the slider's [code]value_changed[/code] logic: label/icon refresh,
## bus volume update, and [signal volume_changed] emission.
static func handle_value_changed(slider: Slider, bus_name: String, new_value: float) -> void:
	slider._update_label_text()
	slider._update_grabber_icon.call_deferred()
	if Engine.is_editor_hint():
		return
	var volume_db: float = compute_bus_volume_db(bus_name, slider, new_value)
	if is_nan(volume_db):
		return
	slider.emit_signal("volume_changed", volume_db)


## Saves the volume on drag end if [param save_volume] is [code]true[/code] and the value actually changed.
static func handle_drag_ended(
		slider: Slider,
		bus_name: String,
		save_volume: bool,
		value_changed: bool,
) -> void:
	if save_volume and value_changed:
		save_persisted_volume(bus_name, value_to_db(slider.value))

#endregion

#region Shared Inspector Property Handling

## Shared [code]_validate_property()[/code] logic for both slider orientations:
## hides irrelevant [Range] properties and toggles read-only/visibility states
## based on the current [member rounded], [member display_label], and [member mute_button] state.
static func validate_slider_property(slider: Slider, property: Dictionary) -> void:
	match property.name:
		# Hide useless range properties for a volume slider
		"page", "exp_edit", "allow_lesser", "allow_greater":
			property.usage = PROPERTY_USAGE_NO_EDITOR
		# Make round_display_volume read only when round is true
		"round_display_volume":
			if slider.rounded or not is_instance_valid(slider.display_label):
				property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		"update_label_in_editor":
			if not is_instance_valid(slider.display_label):
				property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		"_mute_button_create":
			if is_instance_valid(slider.mute_button):
				property.usage = PROPERTY_USAGE_NO_EDITOR
		"_label_create":
			if is_instance_valid(slider.display_label):
				property.usage = PROPERTY_USAGE_NO_EDITOR


## Shared [code]_get_property_list()[/code] logic: injects the dynamic bus name dropdown.
static func build_slider_property_list() -> Array[Dictionary]:
	#HACK : here to prevent the bus names from being included in the save group
	var empty_group: Dictionary[String, Variant] = {
		"name": "",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
	}
	return [empty_group, get_bus_names_enum()]


## Shared [code]_set()[/code] logic: refreshes the label when [member rounded]
## changes, and caches user-set grabber icon overrides so [member grabber_muted_icon]/
## [member grabber_muted_highlight_icon] don't discard them when unmuted.
static func handle_set(slider: Slider, property: StringName, value: Variant) -> void:
	match property:
		# Hides dynamically round_display_volume based on the state of rounded
		"rounded":
			slider.notify_property_list_changed()
			slider._update_label_text.call_deferred()
		# "caches" the user set grabber icon override
		"theme_override_icons/grabber":
			slider._saved_grabber_icon_override = value if value != slider.get_resolved_grabber_muted_icon() else null
		# same thing for grabber highlight
		"theme_override_icons/grabber_highlight":
			slider._saved_grabber_highlight_icon_override = value if value != slider.get_resolved_grabber_muted_highlight_icon() else null


## Sets [param slider]'s [member bus_name] after validating it exists, then
## resynchronizes the slider's value with the new bus's current (or persisted) volume.
## Returns the resulting bus name to assign (either the new one, or the unchanged current one on failure).
static func set_slider_bus_name(slider: Slider, new_bus_name: String, save_volume: bool) -> String:
	if is_valid_bus(new_bus_name):
		sync_slider_with_bus(slider, new_bus_name, save_volume)
		return new_bus_name
	push_error('No bus found with name : "', new_bus_name, '"')
	return slider.bus_name


## Refreshes the Inspector and the label text after [member display_label] is reassigned.
static func set_slider_display_label(slider: Slider, new_label: Label) -> void:
	slider.notify_property_list_changed()
	slider._update_label_text()

#endregion
