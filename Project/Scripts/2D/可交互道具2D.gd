# 2D 道具交互组件：负责贴图、碰撞范围、靠近高亮和拾取。
# item_id：道具数据库编号；item_name：玩家看到的道具名称。
# setup：创建临时 Sprite2D、黄色高亮 Polygon2D、名称 Label 和碰撞形状。
# set_highlight：控制轮廓和名称的可见性，表示玩家是否进入交互范围。
# pickup：增加全局背包数量、记录收集状态并从场景中移除道具。
extends Area2D

@export var item_id := ""
@export var item_name := "道具"
var highlighted := false

func setup(id: String, display_name: String) -> void:
	# 设置道具标识和显示名称，并创建显示节点。
	item_id = id
	item_name = display_name
	var sprite := Sprite2D.new()
	sprite.name = "道具贴图"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 根据道具编号选择对应的像素图标；缺失的可选图标使用通用方块兜底。
	var textures := {
		"baseball_bat": "res://art/pixel/正式PNG/棒球棍.png",
		"crowbar": "res://art/pixel/正式PNG/撬棍.png",
		"battery": "res://art/pixel/正式PNG/电池.png",
		"map": "res://art/pixel/正式PNG/地图.png",
	}
	var texture_path: String = textures.get(id, "res://art/pixel/正式PNG/地图.png")
	sprite.texture = load(texture_path) if ResourceLoader.exists(texture_path) else null
	if sprite.texture == null:
		var icon := Polygon2D.new()
		icon.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
		icon.color = Color("d6a84f")
		add_child(icon)
	sprite.scale = Vector2(0.7, 0.7)
	add_child(sprite)
	var highlight := Polygon2D.new()
	highlight.name = "交互高亮"
	highlight.polygon = PackedVector2Array([Vector2(-18, -18), Vector2(18, -18), Vector2(18, 18), Vector2(-18, 18)])
	highlight.color = Color(1, 0.85, 0.2, 0.35)
	highlight.z_index = -1
	add_child(highlight)
	var label := Label.new()
	label.name = "道具名称"
	label.text = display_name
	label.position = Vector2(-45, -42)
	label.visible = false
	add_child(label)
	var collision := CollisionShape2D.new()
	var collision_shape := CircleShape2D.new()
	collision_shape.radius = 18.0
	collision.shape = collision_shape
	add_child(collision)
	monitoring = false
	monitorable = false
	add_to_group("interactable_items_2d")

func set_highlight(value: bool) -> void:
	# 玩家进入范围后显示黄色轮廓和名称。
	highlighted = value
	$道具贴图.modulate = Color(1.0, 0.9, 0.25, 1.0) if value else Color(1, 1, 1, 1)
	$交互高亮.visible = value
	$道具名称.visible = value

func pickup() -> void:
	# 将道具写入全局背包，并记录为已收集。
	GameState.add_item(item_id)
	GameState.collected_items[item_id] = true
	if item_id in ["baseball_bat", "crowbar"]:
		GameState.set_task(GameState.Task.EQUIP_WEAPON)
	queue_free()
