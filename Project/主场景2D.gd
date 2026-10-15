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
@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $UI/Prompt
@onready var health: ProgressBar = $UI/Health
@onready var stamina: ProgressBar = $UI/Stamina
var nearby_item: Area2D

func _ready() -> void:
	# 初始化地图实体，并根据存档恢复玩家位置。
	_build_map()
	_spawn_items()
	_spawn_enemies()
	if GameState.load_game():
		player.position = Vector2(GameState.player_position.x, GameState.player_position.z)
	$Camera2D.position = player.position
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
	$Camera2D.position = player.position
	GameState.player_position = Vector3(player.position.x, 0.8, player.position.y)
	health.value = GameState.health
	stamina.value = GameState.stamina
	_find_nearby_item()
	if Input.is_action_just_pressed("interact") and nearby_item:
		nearby_item.pickup()
		GameState.save_game()

func _build_map() -> void:
	# 使用临时几何图形构建线性探索地图。
	for point in [Vector2(0, 100), Vector2(-35, 42), Vector2(45, -18), Vector2(-60, -78), Vector2(42, -105)]:
		var marker := Polygon2D.new()
		marker.polygon = PackedVector2Array([Vector2(-18, -18), Vector2(18, -18), Vector2(18, 18), Vector2(-18, 18)])
		marker.position = point
		marker.color = Color(0.22, 0.35, 0.25, 1)
		$World.add_child(marker)
	var road_points := [Vector2(0, 100), Vector2(-35, 42), Vector2(45, -18), Vector2(-60, -78), Vector2(42, -105)]
	for index in range(road_points.size() - 1):
		var line := Line2D.new()
		line.points = PackedVector2Array([road_points[index], road_points[index + 1]])
		line.width = 7.0
		line.default_color = Color(0.28, 0.22, 0.15, 1)
		$World.add_child(line)

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
	$World.add_child(item)

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
	$World.add_child(enemy)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://icon.svg")
	sprite.scale = Vector2(0.04, 0.04)
	sprite.modulate = Color.BLACK
	enemy.add_child(sprite)
	var alert := Label.new()
	alert.name = "Alert"
	alert.text = "!"
	alert.position = Vector2(-6, -30)
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
