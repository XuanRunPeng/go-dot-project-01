# 背包道具按钮：显示图标、名称和整数数量，并提供拖放数据。
# item_data：保存当前按钮对应的道具数据库记录。
# setup：设置按钮文本、图标和悬浮提示；数量统一转换为整数显示。
# _get_drag_data：创建拖动预览，并向图纸面板传递 item 字典。
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
