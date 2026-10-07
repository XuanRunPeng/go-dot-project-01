extends Node3D

const ROAD_MATERIAL := Color(0.28, 0.22, 0.15, 1)
const SIDE_ROAD_MATERIAL := Color(0.22, 0.19, 0.14, 1)
const STATION_MATERIAL := Color(0.72, 0.3, 0.18, 1)
const SHELTER_MATERIAL := Color(0.22, 0.5, 0.38, 1)
const HOUSE_MATERIAL := Color(0.38, 0.3, 0.22, 1)
const SAVE_PATH := "user://game_save.dat"
const SETTINGS_PATH := "user://settings.cfg"

@onready var player: CharacterBody3D = $Player
@onready var pause_panel: PanelContainer = $UI/PausePanel

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_map()
	_load_game()
	_apply_volume()
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_pause()

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
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify({"player_position": [player.global_position.x, player.global_position.y, player.global_position.z]}))

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return
	var raw_data := save_file.get_as_text()
	if not raw_data.strip_edges().begins_with("{"):
		return
	var data = JSON.parse_string(raw_data)
	if data is Dictionary and data.has("player_position") and data.player_position.size() == 3:
		player.global_position = Vector3(data.player_position[0], data.player_position[1], data.player_position[2])

func _apply_volume() -> void:
	var config := ConfigFile.new()
	var volume := 10.0
	if config.load(SETTINGS_PATH) == OK:
		volume = clampf(float(config.get_value("audio", "volume", 10)), 1.0, 10.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume / 10.0))

func _build_map() -> void:
	# The route zigzags through four landmarks, with short search detours.
	_add_road(Vector3(0, 0.12, 17), Vector3(-2, 0.12, 10), ROAD_MATERIAL, 2.8)
	_add_road(Vector3(-2, 0.12, 10), Vector3(3, 0.12, 1), ROAD_MATERIAL, 2.8)
	_add_road(Vector3(3, 0.12, 1), Vector3(-4, 0.12, -9), ROAD_MATERIAL, 2.8)
	_add_road(Vector3(-4, 0.12, -9), Vector3(2, 0.12, -17), ROAD_MATERIAL, 2.8)

	_add_landmark("庇护所", Vector3(0, 0.65, 17), SHELTER_MATERIAL, Vector3(3.2, 1.3, 2.5))
	_add_landmark("基站 1", Vector3(-2, 0.65, 10), STATION_MATERIAL, Vector3(2.2, 1.3, 2.2))
	_add_landmark("基站 2", Vector3(3, 0.65, 1), STATION_MATERIAL, Vector3(2.2, 1.3, 2.2))
	_add_landmark("基站 3", Vector3(-4, 0.65, -9), STATION_MATERIAL, Vector3(2.2, 1.3, 2.2))

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
