@tool
extends EditorProperty

var spin := EditorSpinSlider.new()
var _updating := false
var _connected := false
var _use_range_min: bool
var _use_range_max: bool
var _use_range_step: bool
## Explicit bounds overriding [member Range.min_value]/[member Range.max_value].
## Used when the edited property needs fixed bounds unrelated to the Range
## node's own min/max (e.g. max_value itself, clamped between 100 and 200).
## [code]NAN[/code] means "no override, fall back to _use_range_min/_use_range_max".
var _min_override: float = NAN
var _max_override: float = NAN


func _init(
		use_range_min: bool = false,
		use_range_max: bool = false,
		use_range_step: bool = false,
		allow_greater: bool = true,
		min_override: float = NAN,
		max_override: float = NAN,
) -> void:
	_use_range_min = use_range_min
	_use_range_max = use_range_max
	_use_range_step = use_range_step
	_min_override = min_override
	_max_override = max_override
	add_child(spin)
	add_focusable(spin)
	spin.allow_greater = allow_greater
	spin.value_changed.connect(_on_spin_changed)


func _on_spin_changed(new_value: float) -> void:
	if _updating:
		return
	_update_suffix(new_value)
	emit_changed(get_edited_property(), new_value)


func _update_suffix(current_value: float) -> void:
	var decibels: float = linear_to_db(current_value / 100.0)
	var add_symbol : String = ("+" if decibels > 0.0 else "") 
	var info_text: String = (" (muted)" if decibels == -INF else " (unity gain)" if decibels == 0.0 else "")
	spin.suffix = (" ≈ "+ add_symbol + "%.1f db" % decibels) + info_text


func _update_property() -> void:
	var range_node: Range = get_edited_object()
	var prop_name: StringName = get_edited_property()

	if not _connected:
		range_node.changed.connect(_update_property)
		_connected = true

	_updating = true
	spin.min_value = _min_override if not is_nan(_min_override) else (range_node.min_value if _use_range_min else 0.0)
	spin.max_value = _max_override if not is_nan(_max_override) else (range_node.max_value if _use_range_max else 100.0)
	spin.step = range_node.step if _use_range_step else 1.0
	spin.value = range_node[prop_name]
	_updating = false

	_update_suffix(spin.value)
