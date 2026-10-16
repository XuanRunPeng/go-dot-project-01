extends StaticBody2D

const ITEM_SCRIPT := preload("res://Project/Scripts/2D/可交互道具2D.gd")
@export var health := 3
var visual: Node2D
var loot_table: Array[String] = []

func take_damage(amount: int = 1) -> void:
	health = maxi(0, health - amount)
	if health == 0:
		_drop_loot()
		if is_instance_valid(visual):
			visual.queue_free()
		queue_free()

func _drop_loot() -> void:
	var origin := global_position
	for index in range(loot_table.size()):
		var loot: Area2D = ITEM_SCRIPT.new()
		loot.setup(loot_table[index], loot_table[index])
		loot.position = origin + Vector2(index * 10.0, 0.0)
		get_tree().current_scene.add_child(loot)
