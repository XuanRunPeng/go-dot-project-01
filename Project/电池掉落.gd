# 旧版电池掉落组件：保留给旧场景使用。
# _can_drop_data 只接受电池；_drop_data 发出信号，由主场景增加手电电量。
extends PanelContainer

signal battery_dropped

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.has("item") and data.item.get("id", "") == "battery"

func _drop_data(_at_position: Vector2, _data) -> void:
	battery_dropped.emit()
