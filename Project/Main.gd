extends Node3D

const ROAD_MATERIAL := Color(0.28, 0.22, 0.15, 1)
const SIDE_ROAD_MATERIAL := Color(0.22, 0.19, 0.14, 1)
const STATION_MATERIAL := Color(0.72, 0.3, 0.18, 1)
const SHELTER_MATERIAL := Color(0.22, 0.5, 0.38, 1)
const HOUSE_MATERIAL := Color(0.38, 0.3, 0.22, 1)
const SETTINGS_PATH := "user://settings.cfg"
const ITEMS_PATH := "res://Project/items.json"
const INVENTORY_ITEM_SCRIPT := preload("res://Project/InventoryItem.gd")
const BLUEPRINT_BOARD_SCRIPT := preload("res://Project/BlueprintBoard.gd")
const INTERACTABLE_ITEM_SCRIPT := preload("res://Project/InteractableItem.gd")
const ENEMY_SCRIPT := preload("res://Project/Enemy.gd")
const BATTERY_DROP_SCRIPT := preload("res://Project/BatteryDrop.gd")

@onready var player: CharacterBody3D = $Player
@onready var pause_panel: PanelContainer = $UI/PausePanel
@onready var countdown_label: Label = $UI/HUD/TopBar/Countdown
@onready var objective_label: Label = $UI/HUD/Objective
@onready var map_text: Label = $UI/HUD/MapPanel/Text
@onready var status_message: Label = $UI/HUD/StatusMessage
@onready var interact_prompt: Label = $UI/HUD/InteractPrompt
@onready var mobile_controls: Control = $UI/HUD/MobileControls
@onready var stamina_bar: ProgressBar = $UI/HUD/TopBar/Stamina
@onready var health_bar: ProgressBar = $UI/HUD/TopBar/Health
@onready var flashlight_light: SpotLight3D = $Player/Facing/Flashlight
@onready var flashlight_charge_label: Label = $UI/HUD/FlashlightCharge
var elapsed_time := 0.0
var nearby_item: Area3D
var flashlight_on := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_map()
	_spawn_enemies()
	_spawn_tutorial_items()
	_load_game_state()
	_apply_volume()
	_build_inventory_panel()
	_update_objective_ui()
	flashlight_on = GameState.flashlight_on
	_update_flashlight()
	_layout_hud()
	_play_scene_fade_in()
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_layout_hud)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_pause()
	if event is InputEventScreenTouch:
		mobile_controls.visible = event.pressed

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	elapsed_time += delta
	GameState.elapsed_time = elapsed_time
	countdown_label.text = _format_time(elapsed_time)
	_update_objective_ui()
	_update_nearby_item()
	stamina_bar.value = GameState.stamina
	health_bar.value = GameState.health
	$UI/HUD/TopBar/Stamina/StaminaText.text = "体力条  %s" % player.movement_state
	if Input.is_action_just_pressed("interact"):
		_try_pickup_item()
	if Input.is_action_just_pressed("flashlight"):
		_toggle_flashlight()
	if Input.is_action_just_pressed("map"):
		_on_map_pressed()

func _layout_hud() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var scale_factor := minf(viewport_size.x / 1600.0, viewport_size.y / 900.0)
	$UI/HUD.scale = Vector2.ONE * scale_factor
	$UI/HUD.position = (viewport_size - Vector2(1600.0, 900.0) * scale_factor) * 0.5

func _play_scene_fade_in() -> void:
	var fade := $UI/FadeOverlay
	fade.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 1.2)

func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var remainder := int(seconds) % 60
	return "%02d:%02d" % [minutes, remainder]

func _on_map_pressed() -> void:
	if not GameState.key_items.get("map", false):
		status_message.text = "尚未找到地图"
		return
	$UI/HUD/MapPanel.visible = not $UI/HUD/MapPanel.visible
	_update_objective_ui()

func _on_phone_pressed() -> void:
	_toggle_flashlight()

func _toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	GameState.flashlight_on = flashlight_on
	_update_flashlight()
	_save_game()

func _update_flashlight() -> void:
	flashlight_light.visible = flashlight_on and GameState.flashlight_charge > 0.0
	flashlight_light.light_energy = 5.0 if flashlight_light.visible else 0.0
	flashlight_charge_label.text = "手电电量：%d" % int(maxf(GameState.flashlight_charge, 0.0))

func _on_battery_dropped() -> void:
	if not GameState.has_item("battery"):
		status_message.text = "没有可用电池"
		return
	GameState.inventory["battery"] -= 1
	GameState.flashlight_charge += 50.0
	status_message.text = "电池已装入手电，电量 +50"
	_update_flashlight()
	_save_game()

func _on_backpack_pressed() -> void:
	$UI/HUD/BackpackPanel.visible = not $UI/HUD/BackpackPanel.visible
	$UI/HUD/BackpackOverlay.visible = $UI/HUD/BackpackPanel.visible
	if $UI/HUD/BackpackPanel.visible:
		$UI/HUD/BackpackPanel/InventoryRoot/InventoryBody/ItemList/Items.grab_focus()

func _build_inventory_panel() -> void:
	var panel := $UI/HUD/BackpackPanel
	for child in panel.get_children():
		child.queue_free()
	var root := VBoxContainer.new()
	root.name = "InventoryRoot"
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var close := Button.new()
	close.text = "X"
	close.pressed.connect(func(): _close_backpack())
	header.add_child(close)
	var title := Label.new()
	title.text = "背包 - 道具 / 素材"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var build_button := Button.new()
	build_button.text = "打开建造栏"
	build_button.pressed.connect(func(): _toggle_blueprint_mode(build_button))
	header.add_child(build_button)
	var body := HBoxContainer.new()
	body.name = "InventoryBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var item_list := VBoxContainer.new()
	item_list.name = "ItemList"
	item_list.custom_minimum_size = Vector2(245, 0)
	body.add_child(item_list)
	var tabs := HBoxContainer.new()
	item_list.add_child(tabs)
	for category in ["全部", "道具", "素材", "图纸", "关键道具"]:
		var tab := Button.new()
		tab.text = category
		tab.pressed.connect(_filter_inventory.bind(category))
		tabs.add_child(tab)
	var items_grid := GridContainer.new()
	items_grid.name = "Items"
	items_grid.columns = 3
	items_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.add_child(items_grid)
	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(260, 0)
	body.add_child(details)
	var selected := Label.new()
	selected.name = "SelectedItem"
	selected.text = "选择道具查看信息"
	selected.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(selected)
	var blueprint := PanelContainer.new()
	blueprint.name = "BlueprintBoard"
	blueprint.custom_minimum_size = Vector2(340, 0)
	blueprint.set_script(BLUEPRINT_BOARD_SCRIPT)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	blueprint.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	margin.add_child(content)
	var blueprint_title := Label.new()
	blueprint_title.text = "图纸（将道具拖入此处）"
	blueprint_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(blueprint_title)
	var slots := GridContainer.new()
	slots.name = "Slots"
	slots.columns = 2
	slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(slots)
	var blueprint_status := Label.new()
	blueprint_status.name = "Status"
	blueprint_status.text = "将道具拖入图纸区域"
	blueprint_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(blueprint_status)
	var clear := Button.new()
	clear.text = "清空图纸"
	clear.pressed.connect(blueprint.clear_slots)
	content.add_child(clear)
	body.add_child(blueprint)
	blueprint.visible = false
	var battery_drop := PanelContainer.new()
	battery_drop.name = "BatteryDrop"
	battery_drop.custom_minimum_size = Vector2(220, 70)
	battery_drop.set_script(BATTERY_DROP_SCRIPT)
	var battery_label := Label.new()
	battery_label.text = "将电池拖到这里\n手电电量 +50"
	battery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battery_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	battery_drop.add_child(battery_label)
	battery_drop.battery_dropped.connect(_on_battery_dropped)
	root.add_child(battery_drop)
	_load_inventory_items(items_grid, selected)

func _close_backpack() -> void:
	$UI/HUD/BackpackPanel.visible = false
	$UI/HUD/BackpackOverlay.visible = false

func _toggle_blueprint_mode(button: Button) -> void:
	var blueprint: Control = $UI/HUD/BackpackPanel/InventoryRoot/InventoryBody/BlueprintBoard
	blueprint.visible = not blueprint.visible
	button.text = "关闭建造栏" if blueprint.visible else "打开建造栏"

func _load_inventory_items(items_grid: GridContainer, selected: Label) -> void:
	var file := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is not Array:
		return
	for item in data:
		var button := INVENTORY_ITEM_SCRIPT.new()
		button.custom_minimum_size = Vector2(76, 72)
		item.stack = int(GameState.inventory.get(item.id, 0))
		button.setup(item, load("res://icon.svg"))
		button.pressed.connect(_select_inventory_item.bind(item, selected))
		items_grid.add_child(button)

func _select_inventory_item(item: Dictionary, selected: Label) -> void:
	selected.text = "%s\n\n类型：%s\n数量：%s\n\n可拖入右侧图纸区域作为制作材料。" % [item.name, item.type, item.stack]

func _filter_inventory(category: String) -> void:
	$UI/HUD/StatusMessage.text = "当前分类：" + category

func _spawn_tutorial_items() -> void:
	_spawn_item("baseball_bat", "棒球棍", Vector3(-2.0, 0.65, 15.0))
	_spawn_item("crowbar", "撬棍", Vector3(2.0, 0.65, 15.0))
	_spawn_item("battery", "电池", Vector3(4.0, 0.65, 16.0))
	_spawn_item("map", "地图", Vector3(6.0, 0.65, 16.0))

func _spawn_item(item_id: String, item_name: String, position: Vector3) -> void:
	if GameState.collected_items.get(item_id, false):
		return
	var item: Area3D = INTERACTABLE_ITEM_SCRIPT.new()
	item.setup(item_id, item_name)
	item.position = position
	item.collision_layer = 2
	item.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.2
	collision.shape = shape
	item.add_child(collision)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	mesh.mesh = sphere
	mesh.material_override = _material(Color(0.9, 0.75, 0.18, 1))
	item.add_child(mesh)
	var label := Label3D.new()
	label.text = item_name
	label.position = Vector3(0, 0.7, 0)
	label.font_size = 22
	label.outline_size = 5
	item.add_child(label)
	$MapGeometry.add_child(item)

func _update_nearby_item() -> void:
	nearby_item = null
	var closest_distance := 2.3
	for item in get_tree().get_nodes_in_group("interactable_items"):
		if not is_instance_valid(item):
			continue
		var distance := player.global_position.distance_to(item.global_position)
		if distance < closest_distance:
			closest_distance = distance
			nearby_item = item
	if nearby_item:
		status_message.text = "按 E 拾取：" + nearby_item.item_name
		interact_prompt.text = "E  交互\n" + nearby_item.item_name
		interact_prompt.visible = true
	else:
		status_message.text = ""
		interact_prompt.visible = false

func _try_pickup_item() -> void:
	if nearby_item == null or not is_instance_valid(nearby_item):
		status_message.text = "附近没有可拾取道具"
		return
	var item_name: String = nearby_item.item_name
	if nearby_item.pickup():
		status_message.text = "已拾取：" + item_name
		_save_game()

func _update_objective_ui() -> void:
	var objective := _get_objective()
	objective_label.text = "当前目标：" + objective.title + "\n" + objective.description
	map_text.text = "区域地图\n\n" + objective.map_text

func _get_objective() -> Dictionary:
	match GameState.task:
		GameState.Task.WAKE_UP:
			return {"title": "醒来", "description": "查看屋内并寻找基础武器", "map_text": "庇护所（当前位置）\n→ 搜索屋内武器\n基站 1（未解锁）\n基站 2（未解锁）\n基站 3（未解锁）"}
		GameState.Task.PICKUP_WEAPON:
			return {"title": "获取基础武器", "description": "找到棒球棍或撬棍并拾取", "map_text": "庇护所（当前区域）\n→ 屋内：基础武器\n基站 1（未解锁）\n基站 2（未解锁）\n基站 3（未解锁）"}
		GameState.Task.EQUIP_WEAPON:
			return {"title": "装备武器", "description": "打开背包并装备刚刚获得的武器", "map_text": "庇护所（当前区域）\n→ 打开背包并装备武器\n基站 1（未解锁）\n基站 2（未解锁）\n基站 3（未解锁）"}
		GameState.Task.DEFEAT_FIRST_ENEMY:
			return {"title": "清除门外威胁", "description": "击败门外出现的敌人", "map_text": "庇护所门外（敌人）\n→ 击败敌人\n基站 1（未解锁）\n基站 2（未解锁）\n基站 3（未解锁）"}
		GameState.Task.GET_FLASHLIGHT:
			return {"title": "准备探索", "description": "找到手电图纸和电池，制作手电", "map_text": "庇护所（安全区域）\n→ 获取手电和电池\n基站 1（待探索）\n基站 2（未解锁）\n基站 3（未解锁）"}
		GameState.Task.REACH_FIRST_STATION:
			return {"title": "寻找第一基站", "description": "沿主路线前往第一基站", "map_text": "庇护所\n→ 主路线\n第一基站（目标）\n基站 2（未解锁）\n基站 3（未解锁）"}
		GameState.Task.REPAIR_FIRST_STATION:
			return {"title": "修复第一基站", "description": "收集材料并修复基站道路或入口", "map_text": "第一基站（损坏）\n→ 木头、金属零件、绳子\n基站 2（未解锁）\n基站 3（未解锁）"}
		GameState.Task.GET_STATION_INTEL:
			return {"title": "获取基站情报", "description": "查看第一基站的情报并准备下一段探索", "map_text": "第一基站（已激活）\n→ 获取情报\n基站 2（新区域）\n基站 3（未解锁）"}
		_:
			return {"title": "开始生存", "description": "探索区域、搜索资源并推进主线", "map_text": "庇护所\n第一基站（已激活）\n第二基站（可探索）\n第三基站\n研究所（最终区域）"}

func _on_interact_pressed() -> void:
	_try_pickup_item()

func _on_sprint_pressed() -> void:
	$UI/HUD/StatusMessage.text = "奔跑功能已准备"

func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_panel.visible = paused
	if paused:
		$UI/PausePanel/PauseBox/ContinueButton.grab_focus()

func _on_continue_pressed() -> void:
	_toggle_pause()

func _on_save_and_exit_pressed() -> void:
	_save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Project/Menu.tscn")

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Project/Menu.tscn")

func _save_game() -> void:
	GameState.player_position = player.global_position
	GameState.save_game()

func _load_game_state() -> void:
	if GameState.load_game():
		player.global_position = GameState.player_position
		elapsed_time = GameState.elapsed_time

func _apply_volume() -> void:
	var config := ConfigFile.new()
	var volume := 10.0
	if config.load(SETTINGS_PATH) == OK:
		volume = clampf(float(config.get_value("audio", "volume", 10)), 1.0, 10.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume / 10.0))

func _build_map() -> void:
	# The route now spans the planned large map with irregular base locations.
	_add_road(Vector3(0, 0.12, 100), Vector3(-35, 0.12, 42), ROAD_MATERIAL, 4.0)
	_add_road(Vector3(-35, 0.12, 42), Vector3(45, 0.12, -18), ROAD_MATERIAL, 4.0)
	_add_road(Vector3(45, 0.12, -18), Vector3(-60, 0.12, -78), ROAD_MATERIAL, 4.0)
	_add_road(Vector3(-60, 0.12, -78), Vector3(42, 0.12, -105), ROAD_MATERIAL, 4.0)

	_add_landmark("庇护所", Vector3(0, 0.65, 100), SHELTER_MATERIAL, Vector3(6.0, 1.3, 4.5))
	_add_landmark("基站 1", Vector3(-35, 0.65, 42), STATION_MATERIAL, Vector3(4.5, 1.3, 4.5))
	_add_landmark("基站 2", Vector3(45, 0.65, -18), STATION_MATERIAL, Vector3(4.5, 1.3, 4.5))
	_add_landmark("基站 3", Vector3(-60, 0.65, -78), STATION_MATERIAL, Vector3(4.5, 1.3, 4.5))

	_spawn_large_map_houses()

func _spawn_large_map_houses() -> void:
	_add_house(Vector3(-20, 0.45, 76), Vector3(-12, 0.12, 70))
	_add_house(Vector3(18, 0.45, 62), Vector3(12, 0.12, 58))
	_add_house(Vector3(-66, 0.45, 34), Vector3(-54, 0.12, 32))
	_add_house(Vector3(15, 0.45, 20), Vector3(28, 0.12, 10))
	_add_house(Vector3(75, 0.45, -4), Vector3(62, 0.12, -10))
	_add_house(Vector3(22, 0.45, -42), Vector3(35, 0.12, -35))
	_add_house(Vector3(-90, 0.45, -52), Vector3(-75, 0.12, -60))
	_add_house(Vector3(-22, 0.45, -100), Vector3(-35, 0.12, -92))
	_add_house(Vector3(58, 0.45, -105), Vector3(48, 0.12, -100))

func _spawn_enemies() -> void:
	var stations := [Vector3(-35, 0.8, 42), Vector3(45, 0.8, -18), Vector3(-60, 0.8, -78)]
	var random := RandomNumberGenerator.new()
	random.seed = 20261009
	for station in stations:
		for index in range(4):
			var offset := Vector3(random.randf_range(-14.0, 14.0), 0.0, random.randf_range(-12.0, 12.0))
			_spawn_enemy(station + offset)

func _spawn_enemy(position: Vector3) -> void:
	var enemy: Node3D = ENEMY_SCRIPT.new()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	mesh.mesh = sphere
	mesh.material_override = _material(Color(0.015, 0.015, 0.015, 1))
	enemy.add_child(mesh)
	var alert := Label3D.new()
	alert.name = "Alert"
	alert.text = "!"
	alert.position = Vector3(0, 1.2, 0)
	alert.modulate = Color(1.0, 0.2, 0.1, 1)
	alert.font_size = 40
	alert.outline_size = 8
	alert.visible = false
	enemy.add_child(alert)
	$MapGeometry.add_child(enemy)
	enemy.setup(position)

	_add_house(Vector3(-6, 0.45, 13), Vector3(-4, 0.12, 12))
	_add_house(Vector3(4.5, 0.45, 7), Vector3(1, 0.12, 6))
	_add_house(Vector3(7, 0.45, 2), Vector3(5, 0.12, 2))
	_add_house(Vector3(-7, 0.45, -2), Vector3(-4, 0.12, -4))
	_add_house(Vector3(4, 0.45, -6), Vector3(1, 0.12, -5))
	_add_house(Vector3(-8, 0.45, -13), Vector3(-6, 0.12, -12))
	_add_house(Vector3(6, 0.45, -15), Vector3(1, 0.12, -15))

func _add_road(from: Vector3, to: Vector3, material_color: Color, width: float) -> void:
	var road := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var distance := from.distance_to(to)
	mesh.size = Vector3(width, 0.12, distance)
	road.mesh = mesh
	road.material_override = _material(material_color)
	road.position = (from + to) / 2.0
	road.rotation.y = atan2(to.x - from.x, to.z - from.z)
	$MapGeometry.add_child(road)

func _add_landmark(title: String, position: Vector3, color: Color, size: Vector3) -> void:
	var landmark := StaticBody3D.new()
	landmark.position = position
	$MapGeometry.add_child(landmark)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = _material(color)
	landmark.add_child(mesh_node)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	landmark.add_child(collision)
	_add_label(title, position + Vector3(0, 1.5, 0))

func _add_house(position: Vector3, road_target: Vector3) -> void:
	_add_road(position, road_target, SIDE_ROAD_MATERIAL, 1.2)
	_add_landmark("可搜索屋", position, HOUSE_MATERIAL, Vector3(2.0, 0.9, 1.7))

func _add_label(title: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = title
	label.position = position
	label.font_size = 32
	label.outline_size = 8
	label.modulate = Color(0.9, 0.95, 0.85, 1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	$MapLabels.add_child(label)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
