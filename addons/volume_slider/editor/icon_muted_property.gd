@tool
extends EditorProperty
## Custom [EditorProperty] displaying a [Texture2D] picker with an inline resource preview.
##
## This is a workaround to expose a [code]grabber_muted[/code] icon as a Theme Override
## property. It wraps an [EditorResourcePicker] and, when the user clicks the assigned
## resource, reveals a read-only [EditorInspector] below it to display the resource's
## properties without switching the main Inspector view. Clicking the resource again
## hides the sub-inspector.[br]
## Hope it's useful to someone.
##
## @experimental: This relies on internal Inspector behavior (manually instancing
## [EditorInspector] as a sub-inspector) that is not officially documented as a
## public workflow and may change between Godot versions.

## Resource picker used to assign the [Texture2D] value of the edited property.
var picker := EditorResourcePicker.new()

## Sub-inspector instance created on demand to preview the assigned resource's
## properties. Freed and recreated each time a different resource is selected.
var sub_inspector: EditorInspector

## Container passed to [method EditorProperty.set_bottom_editor] that hosts
## [member sub_inspector] below the resource picker.
var sub_inspector_container: VBoxContainer

## Internal guard used to prevent [method _update_property] from re-triggering
## [signal EditorResourcePicker.resource_changed] while applying an external value.
var _updating := false


# Builds the picker and the [member sub_inspector_container], and
# connects the [EditorResourcePicker] signals needed to drive the preview.
func _init() -> void:
	checkable = true
	picker.base_type = "Texture2D"
	add_child(picker)
	add_focusable(picker)
	picker.resource_changed.connect(_on_resource_changed)
	picker.resource_selected.connect(_on_resource_selected)
	
	sub_inspector_container = VBoxContainer.new()
	sub_inspector_container.visible = false
	sub_inspector_container.clip_contents = true
	add_child(sub_inspector_container)
	set_bottom_editor(sub_inspector_container)


## Called when the user assigns, clears, or replaces the resource via [member picker].
## Propagates the new value to the edited property and closes the sub-inspector,
## since it would otherwise show stale data for the previous resource.
func _on_resource_changed(new_resource: Resource) -> void:
	if _updating:
		return
	emit_changed(get_edited_property(), new_resource)
	_close_sub_inspector()


## Called when the user clicks the currently assigned resource in [member picker].[br]
## Toggles the sub-inspector if the resource is valid
func _on_resource_selected(resource: Resource, _inspect: bool) -> void:
	if not is_instance_valid(resource):
		return
	if is_instance_valid(sub_inspector) and sub_inspector_container.visible:
		_close_sub_inspector()
		return
	_open_sub_inspector(resource)


## Creates a fresh [EditorInspector], edits [param resource] with it to mimick
## the native "resource editor" for the other Theme Overrides Icons
func _open_sub_inspector(resource: Resource) -> void:
	if is_instance_valid(sub_inspector):
		sub_inspector_container.remove_child(sub_inspector)
		sub_inspector.free()
	sub_inspector = EditorInspector.new()
	sub_inspector.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sub_inspector.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sub_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sub_inspector.edit(resource)
	sub_inspector_container.add_child(sub_inspector)
	sub_inspector_container.visible = true
	select()


## Hides [member sub_inspector_container], resets its minimum size, and frees
## [member sub_inspector] immediately (rather than deferring with [method Node.queue_free])
## to avoid a visual artifact where the empty inspector background remains visible.
func _close_sub_inspector() -> void:
	sub_inspector_container.visible = false
	sub_inspector_container.custom_minimum_size = Vector2.ZERO
	if is_instance_valid(sub_inspector):
		sub_inspector_container.remove_child(sub_inspector)
		sub_inspector.free()
	deselect()


## Refreshes [member picker] to reflect the edited object's current value.[br]
## If the property is unset ([code]null[/code]) and the edited object exposes a
## [method Object.get_resolved_grabber_muted_icon] method, the picker falls back
## to displaying that resolved icon instead of leaving the property empty.
func _update_property() -> void:
	var object: Object = get_edited_object()
	var prop_name: String = get_edited_property()
	var raw_value: Texture2D = object[prop_name]
	
	set_checked(raw_value != null)
	
	_updating = true
	if raw_value == null:
		var resolved_icon: Texture2D = null
		match prop_name:
			"grabber_muted_highlight_icon":
				if object.has_method("get_resolved_grabber_muted_highlight_icon"):
					resolved_icon = object.get_resolved_grabber_muted_highlight_icon()
			"grabber_muted_icon":
				if object.has_method("get_resolved_grabber_muted_icon"):
					resolved_icon = object.get_resolved_grabber_muted_icon()
		picker.edited_resource = resolved_icon if is_instance_valid(resolved_icon) else null
	else:
		picker.edited_resource = raw_value
	_updating = false
