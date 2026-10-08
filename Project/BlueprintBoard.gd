extends PanelContainer

@onready var slots: GridContainer = $Margin/Content/Slots
@onready var status: Label = $Margin/Content/Status

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.has("item")

func _drop_data(_at_position: Vector2, data) -> void:
	var item: Dictionary = data.item
	var slot := Label.new()
	slot.custom_minimum_size = Vector2(110, 54)
	slot.text = item.name
	slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_theme_color_override("font_color", Color(0.9, 0.9, 0.65))
	slots.add_child(slot)
	status.text = "已放入图纸：" + item.name

func clear_slots() -> void:
	for child in slots.get_children():
		child.queue_free()
	status.text = "将道具拖入图纸区域"
