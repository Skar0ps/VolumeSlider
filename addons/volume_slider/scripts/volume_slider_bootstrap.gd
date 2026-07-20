## Applies every persisted volume to its corresponding AudioServer bus at
## startup, then frees itself immediately since its job is done.
extends Node

func _ready() -> void:
	var config_path : String = VolumeUtils.get_config_path()
	if VolumeUtils.has_persisted_volumes(config_path):
		for bus_name : String in VolumeUtils.get_bus_names():
			var bus_index : int = AudioServer.get_bus_index(bus_name)
			if bus_index == -1:
				continue
			var volume_db : float = VolumeUtils.load_persisted_volume(bus_name, config_path)
			AudioServer.set_bus_volume_db(bus_index, volume_db)
	queue_free()
