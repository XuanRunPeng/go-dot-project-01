# 2D 玩家控制器：处理 WASD 移动、奔跑、潜行和体力。
# walk_speed：普通行走速度；run_speed：按住 Shift 时的速度。
# stealth_speed：按住 Ctrl 时的速度。
# stamina_drain：奔跑消耗速率；stamina_recovery：停止奔跑后的恢复速率。
# movement_state：向敌人 AI 和 HUD 暴露“行走、奔跑、潜行”状态。
# _physics_process：读取输入、计算速度和移动角色。
extends CharacterBody2D

@export var walk_speed := 90.0
@export var run_speed := 145.0
@export var stealth_speed := 42.0
@export var stamina_drain := 18.0
@export var stamina_recovery := 12.0
@export var melee_damage := 1
@export var melee_range := 42.0
@export var melee_cooldown := 0.35
var movement_state := "行走"
var melee_timer := 0.0

func _physics_process(delta: float) -> void:
	melee_timer = maxf(0.0, melee_timer - delta)
	# 读取输入并计算本帧移动状态。
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := Input.is_action_pressed("sprint") and input.length_squared() > 0.01 and GameState.stamina > 0.0
	var stealth := Input.is_action_pressed("stealth") and not running
	var speed := walk_speed
	if running:
		# 奔跑提高移动速度并消耗体力。
		movement_state = "奔跑"
		speed = run_speed
		GameState.stamina = maxf(0.0, GameState.stamina - stamina_drain * delta)
	else:
		# 行走或潜行时恢复体力。
		movement_state = "潜行" if stealth else "行走"
		speed = stealth_speed if stealth else walk_speed
		GameState.stamina = minf(100.0, GameState.stamina + stamina_recovery * delta)
	velocity = input * speed
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_attack_towards(get_global_mouse_position())

func _attack_towards(target: Vector2) -> void:
	if melee_timer > 0.0 or not GameState.has_item("baseball_bat"):
		return
	melee_timer = melee_cooldown
	var direction := global_position.direction_to(target)
	var hit_position := global_position + direction * melee_range
	for enemy in get_tree().get_nodes_in_group("enemies_2d"):
		if is_instance_valid(enemy) and enemy.global_position.distance_to(hit_position) <= 18.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(melee_damage)
	# 近战射线只允许命中方向上的第一个障碍，避免隔着木头攻击箱子。
	var query := PhysicsRayQueryParameters2D.create(global_position, hit_position)
	query.collision_mask = 4
	query.exclude = [self]
	var ray_hit := get_world_2d().direct_space_state.intersect_ray(query)
	var first_collider = ray_hit.get("collider")
	var obstacle_type := str(first_collider.get_meta("obstacle_type", "")) if is_instance_valid(first_collider) else ""
	if obstacle_type == "destructible_obstacle":
		if first_collider.has_method("take_damage"):
			first_collider.take_damage(melee_damage)
	var slash := Line2D.new()
	slash.width = 3.0
	slash.default_color = Color(1.0, 0.85, 0.3, 0.9)
	slash.points = PackedVector2Array([global_position, hit_position])
	get_tree().current_scene.add_child(slash)
	var tween := create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.12)
	tween.tween_callback(slash.queue_free)
