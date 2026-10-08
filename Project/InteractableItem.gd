extends Area3D

@export var item_id := ""
@export var item_name := "道具"
@export var amount := 1
var picked_up := false

func setup(id: String, display_name: String, quantity := 1) -> void:
	item_id = id
	item_name = display_name
	amount = quantity
	add_to_group("interactable_items")

func pickup() -> bool:
	if picked_up:
		return false
	picked_up = true
	GameState.add_item(item_id, amount)
	GameState.collected_items[item_id] = true
	if item_id in ["baseball_bat", "crowbar"]:
		GameState.set_task(GameState.Task.EQUIP_WEAPON)
	if item_id == "battery":
		GameState.set_task(GameState.Task.GET_FLASHLIGHT)
	if item_id == "map":
		GameState.key_items["map"] = true
		GameState.set_task(GameState.Task.REACH_FIRST_STATION)
	queue_free()
	return true
