# 2D 游戏主场景：创建地图、玩家、道具、敌人和运行时界面。
# 常量：ITEM_SCRIPT 和 ENEMY_SCRIPT 分别指向动态生成的道具与敌人脚本。
# 节点引用：player、prompt、health、stamina 连接场景中的玩家和 HUD 控件。
# 运行流程：_ready 初始化世界，_process 更新状态，_exit_tree 保存位置。
# 地图流程：_build_map 创建路线，_spawn_items 创建道具，_spawn_enemies 创建敌人。
# 交互流程：_find_nearby_item 负责范围高亮，按下 interact 后调用道具 pickup。
# 过渡流程：_show_arrival_fade 用黑色遮罩承接开场介绍和游戏画面。
extends Node2D

const ITEM_SCRIPT: GDScript = preload("res://Project/Scripts/2D/可交互道具2D.gd")
const ENEMY_SCRIPT: GDScript = preload("res://Project/Scripts/2D/敌人2D.gd")
const DESTRUCTIBLE_SCRIPT: GDScript = preload("res://Project/Scripts/2D/可破坏物2D.gd")
const ENVIRONMENT_LAYER := 4
@onready var player: CharacterBody2D = $玩家
@onready var prompt: Label = $界面/交互提示
@onready var health: ProgressBar = $界面/生命条
@onready var stamina: ProgressBar = $界面/体力条
var nearby_item: Area2D

func _ready() -> void:
	# 初始化地图实体，并根据存档恢复玩家位置。
	_build_map()
	_spawn_items()
	# 不生成测试怪物，保留正式敌人系统供后续关卡使用。
	_setup_supermarket_collisions()
	_spawn_corner_loot()
	if not GameState.has_item("baseball_bat") and not GameState.has_item("crowbar"):
		GameState.add_item("baseball_bat")
		GameState.equipped_item = "baseball_bat"
	if GameState.load_game():
		player.position = Vector2(GameState.player_position.x, GameState.player_position.z)
	else:
		player.position = Vector2(GameState.player_position.x, GameState.player_position.z)
	$主相机.position = player.position
	_show_arrival_fade()

func _setup_supermarket_collisions() -> void:
	# 为超市木头障碍和箱子按精灵实际尺寸创建碰撞体。
	var wood_root := get_node_or_null("世界/超市木头障碍")
	if wood_root:
		for child in wood_root.get_children():
			if child is Sprite2D:
				_add_sprite_collision(child, false)
	var crate_root := get_node_or_null("世界/超市可破坏箱子")
	if crate_root:
		for child in crate_root.get_children():
			if child is Sprite2D:
				_add_sprite_collision(child, true)

func _add_sprite_collision(sprite: Sprite2D, destructible: bool) -> void:
	if sprite.texture == null:
		return
	var body: StaticBody2D = DESTRUCTIBLE_SCRIPT.new() if destructible else StaticBody2D.new()
	body.name = sprite.name + ("_可破坏碰撞体" if destructible else "_碰撞体")
	body.collision_layer = ENVIRONMENT_LAYER
	body.collision_mask = 5
	body.set_meta("obstacle_type", "destructible_obstacle" if destructible else "solid_obstacle")
	if destructible:
		body.add_to_group("destructible_2d")
		body.set_meta("health", 3)
		body.set("visual", sprite)
		body.set("loot_table", _loot_for_crate(sprite.name))
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = sprite.texture.get_size()
	collision.shape = shape
	body.add_child(collision)
	$世界.add_child(body)
	body.global_transform = sprite.global_transform

func _loot_for_crate(crate_name: String) -> Array[String]:
	var tables: Dictionary = {
		"箱子1": ["金属零件", "绳子"],
		"箱子2": ["电池", "报警器"],
		"箱子3": ["金属零件", "电池"],
		"箱子4": ["绳子", "报警器"],
		"箱子5": ["金属零件"],
		"箱子6": ["电池", "绳子"]
	}
	var result: Array[String] = []
	for item in tables.get(crate_name, ["金属零件"]):
		result.append(str(item))
	return result

func _spawn_corner_loot() -> void:
	# 把食物和近战武器放在超市地图边角，避免与箱子重叠。
	_spawn_item("bread", "面包", Vector2(1440, -180))
	_spawn_item("can", "罐头", Vector2(1480, -180))
	_spawn_item("energy_bar", "能量棒", Vector2(1440, 380))
	_spawn_item("water", "饮用水", Vector2(1480, 380))
	_spawn_item("baseball_bat", "棒球棍", Vector2(360, 380))
	_spawn_item("crowbar", "撬棍", Vector2(400, 380))
	_spawn_item("spear", "斧头", Vector2(1540, 80))

func _show_arrival_fade() -> void:
	# 用黑色遮罩淡出承接开场文字，避免直接跳入游戏画面。
	var layer := CanvasLayer.new()
	layer.layer = 20
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cover)
	add_child(layer)
	var tween := create_tween()
	tween.tween_property(cover, "modulate:a", 0.0, 1.1)
	tween.tween_callback(layer.queue_free)

func _process(_delta: float) -> void:
	# 每帧同步镜头、玩家状态和附近道具提示。
	$主相机.position = player.position
	GameState.player_position = Vector3(player.position.x, 0.8, player.position.y)
	health.value = GameState.health
	stamina.value = GameState.stamina
	_find_nearby_item()
	if Input.is_action_just_pressed("interact") and nearby_item:
		nearby_item.pickup()
		GameState.save_game()

func _build_map() -> void:
	# 使用临时几何图形构建线性探索地图。
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2(-160, -115), Vector2(160, -115), Vector2(160, 115), Vector2(-160, 115)
	])
	ground.color = Color(0.28, 0.34, 0.28, 1.0)
	ground.z_index = -10
	$世界.add_child(ground)
	_add_obstacle(Vector2(-28, 78), Vector2(18, 8))
	_add_obstacle(Vector2(27, 57), Vector2(16, 9))
	_add_obstacle(Vector2(-69, 27), Vector2(14, 10))
	_add_obstacle(Vector2(76, -5), Vector2(16, 9))
	_add_obstacle(Vector2(-93, -48), Vector2(18, 10))
	for point in [Vector2(0, 100), Vector2(-35, 42), Vector2(45, -18), Vector2(-60, -78), Vector2(42, -105)]:
		var marker := Polygon2D.new()
		marker.polygon = PackedVector2Array([Vector2(-24, -24), Vector2(24, -24), Vector2(24, 24), Vector2(-24, 24)])
		marker.position = point
		marker.color = Color(0.22, 0.35, 0.25, 1)
		$世界.add_child(marker)
	_spawn_houses()
	var road_points := [Vector2(0, 100), Vector2(-35, 42), Vector2(45, -18), Vector2(-60, -78), Vector2(42, -105)]
	for index in range(road_points.size() - 1):
		var line := Line2D.new()
		line.points = PackedVector2Array([road_points[index], road_points[index + 1]])
		line.width = 7.0
		line.default_color = Color(0.28, 0.22, 0.15, 1)
		$世界.add_child(line)
	for branch in [
		[Vector2(-35, 42), Vector2(-78, 56)],
		[Vector2(45, -18), Vector2(92, 18)],
		[Vector2(-60, -78), Vector2(-106, -40)],
		[Vector2(-60, -78), Vector2(-28, -110)]
	]:
		var side_road := Line2D.new()
		side_road.points = PackedVector2Array(branch)
		side_road.width = 5.0
		side_road.default_color = Color(0.25, 0.2, 0.15, 1)
		$世界.add_child(side_road)

func _spawn_houses() -> void:
	# 房屋按星露谷式平面比例放大，作为道路两侧清晰可辨的探索地标。
	var houses := [
		Vector2(-20, 76), Vector2(18, 63), Vector2(-58, 30),
		Vector2(24, 14), Vector2(67, -8), Vector2(34, -38),
		Vector2(-78, -56), Vector2(-34, -94), Vector2(50, -96),
		Vector2(-96, 52), Vector2(96, 17), Vector2(-108, -38)
	]
	for house_position in houses:
		_add_house(house_position)

func _add_house(point: Vector2) -> void:
	# 房屋主体、屋顶和实体碰撞使用同一尺寸，避免视觉与碰撞错位。
	var house := StaticBody2D.new()
	house.position = point
	house.collision_layer = ENVIRONMENT_LAYER
	house.collision_mask = ENVIRONMENT_LAYER
	house.set_meta("obstacle_type", "solid_obstacle")
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(14, -8), Vector2(14, 10), Vector2(-14, 10)
	])
	body.color = Color(0.32, 0.29, 0.24, 1.0)
	house.add_child(body)
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-17, -8), Vector2(0, -19), Vector2(17, -8)
	])
	roof.color = Color(0.42, 0.24, 0.2, 1.0)
	house.add_child(roof)
	var door := Polygon2D.new()
	door.polygon = PackedVector2Array([
		Vector2(-3, 10), Vector2(3, 10), Vector2(3, 1), Vector2(-3, 1)
	])
	door.color = Color(0.14, 0.13, 0.12, 1.0)
	house.add_child(door)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 18)
	collision.shape = shape
	house.add_child(collision)
	$世界.add_child(house)

func _add_obstacle(point: Vector2, dimensions: Vector2) -> void:
	# 使用可视矩形与静态碰撞体表示地图障碍。
	var obstacle := StaticBody2D.new()
	obstacle.position = point
	obstacle.collision_layer = ENVIRONMENT_LAYER
	obstacle.collision_mask = ENVIRONMENT_LAYER
	obstacle.set_meta("obstacle_type", "solid_obstacle")
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-dimensions.x * 0.5, -dimensions.y * 0.5),
		Vector2(dimensions.x * 0.5, -dimensions.y * 0.5),
		Vector2(dimensions.x * 0.5, dimensions.y * 0.5),
		Vector2(-dimensions.x * 0.5, dimensions.y * 0.5)
	])
	visual.color = Color(0.25, 0.24, 0.2, 1.0)
	obstacle.add_child(visual)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	collision.shape = shape
	obstacle.add_child(collision)
	$世界.add_child(obstacle)

func _spawn_items() -> void:
	# 起始区域只保留地图，武器统一放在超市角落。
	_spawn_item("map", "地图", Vector2(12, 91))

func _spawn_item(id: String, title: String, point: Vector2) -> void:
	# 已拾取的道具不重复生成。
	if GameState.collected_items.get(id, false):
		return
	var item: Area2D = ITEM_SCRIPT.new()
	item.setup(id, title)
	item.position = point
	$世界.add_child(item)
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	item.add_child(collision)

func _spawn_enemies() -> void:
	# 围绕三个基站生成不规则分布的敌人。
	var bases := [Vector2(-35, 42), Vector2(45, -18), Vector2(-60, -78)]
	for base in bases:
		for index in range(4):
			var angle: float = float(index) * 1.7 + base.x * 0.02
			_spawn_enemy(base + Vector2(cos(angle) * (10.0 + index), sin(angle) * (8.0 + index)))

func _spawn_enemy(point: Vector2) -> void:
	# 创建纯黑圆形敌人和警戒感叹号。
	var enemy: Node2D = ENEMY_SCRIPT.new()
	$世界.add_child(enemy)
	enemy.position = point
	var body := Polygon2D.new()
	body.name = "敌人黑色圆形"
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(Vector2(cos(angle), sin(angle)) * 7.0)
	body.polygon = points
	body.color = Color.BLACK
	enemy.add_child(body)
	var alert := Label.new()
	alert.name = "警戒标记"
	alert.text = "!"
	alert.position = Vector2(-6, -22)
	alert.modulate = Color(1, 0.2, 0.1, 1)
	alert.visible = false
	enemy.add_child(alert)
	enemy.setup(point, player)

func _find_nearby_item() -> void:
	# 找出最近道具，并切换高亮、名称和交互提示。
	nearby_item = null
	var best := 24.0
	for item in get_tree().get_nodes_in_group("interactable_items_2d"):
		var distance := player.position.distance_to(item.position)
		item.set_highlight(distance <= 24.0)
		if distance <= best:
			best = distance
			nearby_item = item
	if nearby_item:
		prompt.text = "E 交互：" + nearby_item.item_name
		prompt.visible = true
	else:
		prompt.visible = false

func _exit_tree() -> void:
	if is_instance_valid(player):
		GameState.player_position = Vector3(player.position.x, 0.8, player.position.y)
		GameState.save_game()
