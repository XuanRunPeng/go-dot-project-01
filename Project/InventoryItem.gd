extends Button

var item_data: Dictionary

func setup(data: Dictionary, icon_texture: Texture2D) -> void:
	item_data = data
	text = data.name + "\n" + str(data.stack)
	icon = icon_texture
	tooltip_text = "%s\n类型：%s\n堆叠：%s" % [data.name, data.type, data.stack]

func _get_drag_data(_at_position: Vector2):
	var preview := Label.new()
	preview.text = item_data.name
	preview.add_theme_color_override("font_color", Color.WHITE)
	set_drag_preview(preview)
	return {"item": item_data}
