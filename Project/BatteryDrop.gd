extends PanelContainer

signal battery_dropped

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.has("item") and data.item.get("id", "") == "battery"

func _drop_data(_at_position: Vector2, _data) -> void:
	battery_dropped.emit()
