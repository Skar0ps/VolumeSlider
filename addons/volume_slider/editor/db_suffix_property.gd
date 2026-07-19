@tool
extends EditorProperty

var spin := EditorSpinSlider.new()
var _updating := false
var _connected := false
var _use_range_min : bool
var _use_range_max : bool
var _use_range_step : bool

func _init(use_range_min: bool = false, use_range_max: bool = false, use_range_step: bool = false,allow_greater: bool = true) -> void:
	_use_range_min = use_range_min
	_use_range_max = use_range_max
	_use_range_step = use_range_step
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
	var decibels : float = linear_to_db(current_value / 100.0)
	spin.suffix = ("%.1f db" % decibels) + (" (muted)" if decibels == -INF else "") 


func _update_property() -> void:
	var range_node : Range = get_edited_object()
	var prop_name : StringName = get_edited_property()
	
	if not _connected:
		range_node.changed.connect(_update_property)
		_connected = true
	
	_updating = true
	spin.min_value = range_node.min_value if _use_range_min else 0.0
	spin.max_value = range_node.max_value if _use_range_max else 100.0
	spin.step = range_node.step if _use_range_step else 1.0
	spin.value = range_node[prop_name]
	_updating = false
	
	_update_suffix(spin.value)
