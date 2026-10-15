# 2D 游戏主场景：创建地图、玩家、道具、敌人和运行时界面。
# 常量：ITEM_SCRIPT 和 ENEMY_SCRIPT 分别指向动态生成的道具与敌人脚本。
# 节点引用：player、prompt、health、stamina 连接场景中的玩家和 HUD 控件。
# 运行流程：_ready 初始化世界，_process 更新状态，_exit_tree 保存位置。
# 地图流程：_build_map 创建路线，_spawn_items 创建道具，_spawn_enemies 创建敌人。
# 交互流程：_find_nearby_item 负责范围高亮，按下 interact 后调用道具 pickup。
# 过渡流程：_show_arrival_fade 用黑色遮罩承接开场介绍和游戏画面。
extends Node2D

const ITEM_SCRIPT := preload("res://Project/可交互道具2D.gd")
const ENEMY_SCRIPT := preload("res://Project/敌人2D.gd")
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
	_spawn_enemies()
	if GameState.load_game():
		player.position = Vector2(GameState.player_position.x, GameState.player_position.z)
	else:
		player.position = Vector2(GameState.player_position.x, GameState.player_position.z)
	$主相机.position = player.position
	_show_arrival_fade()

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
	# 在起始庇护所附近放置原型道具。
	_spawn_item("baseball_bat", "棒球棍", Vector2(-4, 94))
	_spawn_item("crowbar", "撬棍", Vector2(5, 96))
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
	# 创建敌人贴图和警戒感叹号。
	var enemy: Node2D = ENEMY_SCRIPT.new()
	$世界.add_child(enemy)
	enemy.position = point
	var sprite := AnimatedSprite2D.new()
	sprite.name = "敌人精灵图"
	# 当前先用单帧原型；接入多帧精灵图时只替换 SpriteFrames。
	var frames := SpriteFrames.new()
	frames.add_animation("待机")
	frames.set_animation_speed("待机", 4.0)
	frames.add_frame("待机", load("res://art/pixel/正式PNG/敌人.png"))
	sprite.sprite_frames = frames
	sprite.animation = "待机"
	sprite.autoplay = "待机"
	sprite.scale = Vector2(0.32, 0.32)
	sprite.modulate = Color.BLACK
	enemy.add_child(sprite)
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
