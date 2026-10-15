# 2D 敌人状态机：游荡、警戒、追击和攻击。
# State：WANDER 为常态，ALERT 为警戒，CHASE 为追击，ATTACK 为攻击。
# detection_radius：普通感知范围；奔跑玩家会扩大敌人的感知范围。
# alert_elapsed：累计警戒时间，达到 1.5 秒才锁定玩家。
# wander_target：出生点附近的随机游荡目标；attack_cooldown：攻击间隔。
# setup：设置出生点、目标玩家和随机种子；_physics_process：驱动状态机。
# _wander、_choose_target、_move_towards：分别负责游荡、选点和移动。
extends CharacterBody2D

enum State { WANDER, ALERT, CHASE, ATTACK }
@export var detection_radius := 190.0
@export var wander_radius := 105.0
@export var attack_radius := 24.0
@export var move_speed := 58.0
var state := State.WANDER
var spawn_point := Vector2.ZERO
var wander_target := Vector2.ZERO
var player: CharacterBody2D
var alert_elapsed := 0.0
var attack_cooldown := 0.0
var rng := RandomNumberGenerator.new()
var alert: Label

func _ready() -> void:
	# 敌人自身持有碰撞体，确保所有动态生成的敌人都能参与地图碰撞。
	collision_layer = 2
	collision_mask = 5
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	collision.shape = shape
	add_child(collision)

func setup(origin: Vector2, target: CharacterBody2D) -> void:
	# 记录出生点、玩家目标和可复现随机种子。
	spawn_point = origin
	position = origin
	player = target
	rng.seed = int(origin.x * 97.0 + origin.y * 31.0 + 20261009.0)
	_choose_target()

func _physics_process(delta: float) -> void:
	# 执行感知、状态切换和移动。
	if player == null:
		return
	if alert == null:
		alert = get_node_or_null("警戒标记")
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var distance := position.distance_to(player.position)
	var detection := detection_radius
	if player.movement_state == "奔跑":
		detection *= 1.6
	if player.movement_state == "潜行":
		# 潜行玩家不会触发警戒，敌人恢复游荡。
		state = State.WANDER
		alert_elapsed = 0.0
		if is_instance_valid(alert):
			alert.visible = false
		_wander(delta)
		return
	if state == State.WANDER and distance <= detection:
		# 进入警戒范围后先显示感叹号并开始延迟计时。
		state = State.ALERT
		alert_elapsed = 0.0
		if is_instance_valid(alert):
			alert.visible = true
	if state == State.ALERT:
		# 警戒持续 1.5 秒后才锁定玩家。
		alert_elapsed += delta
		if is_instance_valid(alert):
			alert.visible = true
		if distance > detection:
			state = State.WANDER
			alert_elapsed = 0.0
		elif alert_elapsed >= 1.5:
			state = State.ATTACK if distance <= attack_radius else State.CHASE
	if state == State.WANDER:
		_wander(delta)
	elif state == State.CHASE:
		# 追击速度低于玩家奔跑速度。
		if is_instance_valid(alert):
			alert.visible = true
		_move_towards(player.position, delta)
	elif state == State.ATTACK:
		# 在攻击冷却结束后扣除玩家生命。
		if is_instance_valid(alert):
			alert.visible = true
		if distance > attack_radius * 1.5:
			state = State.CHASE
		elif attack_cooldown <= 0.0:
			GameState.health = maxf(0.0, GameState.health - 10.0)
			attack_cooldown = 1.2

func _wander(delta: float) -> void:
	# 在出生点附近进行随机游荡。
	if position.distance_to(wander_target) < 0.8:
		_choose_target()
	_move_towards(wander_target, delta, 0.45)

func _choose_target() -> void:
	# 选择出生点附近的不规则目标点。
	wander_target = spawn_point + Vector2(rng.randf_range(-wander_radius, wander_radius), rng.randf_range(-wander_radius, wander_radius))

func _move_towards(target: Vector2, delta: float, multiplier := 1.0) -> void:
	# 按当前速度向目标移动。
	var direction := position.direction_to(target)
	velocity = direction * move_speed * multiplier
	move_and_slide()
	velocity = Vector2.ZERO
