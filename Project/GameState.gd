extends Node

const SAVE_PATH := "user://game_save.dat"
const SAVE_VERSION := 2

enum Task {
	WAKE_UP,
	PICKUP_WEAPON,
	EQUIP_WEAPON,
	DEFEAT_FIRST_ENEMY,
	GET_FLASHLIGHT,
	REACH_FIRST_STATION,
	REPAIR_FIRST_STATION,
	GET_STATION_INTEL,
	SURVIVAL_LOOP
}

var task: Task = Task.WAKE_UP
var player_position := Vector3(0.0, 0.8, 17.0)
var health := 100.0
var stamina := 100.0
var inventory: Dictionary = {}
var equipped_item := ""
var key_items: Dictionary = {}
var stations: Dictionary = {"station_1": false, "station_2": false, "station_3": false}
var searched_houses: Dictionary = {}
var collected_items: Dictionary = {}
var elapsed_time := 0.0
var flashlight_on := false
var flashlight_charge := 0.0

func start_new_game() -> void:
	task = Task.WAKE_UP
	player_position = Vector3(0.0, 0.8, 17.0)
	health = 100.0
	stamina = 100.0
	inventory = {}
	equipped_item = ""
	key_items = {}
	stations = {"station_1": false, "station_2": false, "station_3": false}
	searched_houses = {}
	collected_items = {}
	elapsed_time = 0.0
	flashlight_on = false
	flashlight_charge = 0.0

func set_task(next_task: Task) -> void:
	if next_task > task:
		task = next_task

func add_item(item_id: String, amount := 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	if item_id == "map":
		key_items["map"] = true
		set_task(Task.REACH_FIRST_STATION)

func has_item(item_id: String, amount := 1) -> bool:
	return int(inventory.get(item_id, 0)) >= amount

func save_game() -> bool:
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		return false
	save_file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"task": task,
		"player_position": [player_position.x, player_position.y, player_position.z],
		"health": health,
		"stamina": stamina,
		"inventory": inventory,
		"equipped_item": equipped_item,
		"key_items": key_items,
		"stations": stations,
		"searched_houses": searched_houses,
		"collected_items": collected_items,
		"elapsed_time": elapsed_time
		,"flashlight_on": flashlight_on
		,"flashlight_charge": flashlight_charge
	}))
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return false
	var raw_data := save_file.get_as_text()
	if not raw_data.strip_edges().begins_with("{"):
		return false
	var data = JSON.parse_string(raw_data)
	if not data is Dictionary or not data.has("player_position"):
		return false
	var position_data: Array = data.player_position
	if position_data.size() != 3:
		return false
	player_position = Vector3(position_data[0], position_data[1], position_data[2])
	task = int(data.get("task", Task.WAKE_UP)) as Task
	health = float(data.get("health", 100.0))
	stamina = float(data.get("stamina", 100.0))
	inventory = data.get("inventory", {})
	equipped_item = str(data.get("equipped_item", ""))
	key_items = data.get("key_items", {})
	stations = data.get("stations", {"station_1": false, "station_2": false, "station_3": false})
	searched_houses = data.get("searched_houses", {})
	collected_items = data.get("collected_items", {})
	elapsed_time = float(data.get("elapsed_time", 0.0))
	flashlight_on = bool(data.get("flashlight_on", false))
	flashlight_charge = float(data.get("flashlight_charge", 0.0))
	return true

func has_valid_save() -> bool:
	return load_game()
