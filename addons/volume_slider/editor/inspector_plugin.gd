@tool
extends EditorInspectorPlugin

const DB_SUFFIX_PROPERTY := preload("res://addons/volume_slider/editor/db_suffix_property.gd")
const ICON_MUTED_PROPERTY := preload("res://addons/volume_slider/editor/icon_muted_property.gd")

func _can_handle(object: Object) -> bool:
	return object is HVolumeSlider or object is VVolumeSlider

func _parse_group(object: Object, group: String) -> void:
	#HACK adds the grabber_muted_icon to theme overrides, it's the only way i found that worked reliably
	if object is HVolumeSlider or object is VVolumeSlider:
		if group == "Theme Overrides/icons":
			add_property_editor("grabber_muted_icon", ICON_MUTED_PROPERTY.new(), false, "Grabber Muted")
			add_property_editor("grabber_muted_highlight_icon", ICON_MUTED_PROPERTY.new(), false, "Grabber Muted Highlight")

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	match name:
		"min_value":
			add_property_editor(name, DB_SUFFIX_PROPERTY.new(false, true, false))
			return true
		"max_value":
			add_property_editor(name, DB_SUFFIX_PROPERTY.new(true, false, false))
			return true
		"value":
			add_property_editor(name, DB_SUFFIX_PROPERTY.new(true, true, true, false))
			return true
		"grabber_muted_icon","grabber_muted_highlight_icon":
			return true
	return false
