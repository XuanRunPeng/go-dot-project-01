extends Node3D

enum State { WANDER, ALERT, CHASE, ATTACK }

@export var wander_radius := 8.0
@export var detection_radius := 13.0
@export var attack_radius := 1.8
@export var move_speed := 2.2
var state := State.WANDER
var spawn_point := Vector3.ZERO
var wander_target := Vector3.ZERO
var player: CharacterBody3D
var alert_label: Label3D
var attack_cooldown := 0.0
var alert_elapsed := 0.0
var rng := RandomNumberGenerator.new()

func setup(origin: Vector3) -> void:
	spawn_point = origin
	global_position = origin
	rng.randomize()
	_choose_wander_target()

func _ready() -> void:
	player = get_tree().current_scene.get_node_or_null("Player")
	alert_label = get_node_or_null("Alert")

func _physics_process(delta: float) -> void:
	if player == null:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var distance := global_position.distance_to(player.global_position)
	var detection := _get_detection_radius()
	if player.movement_state == "潜行":
		alert_elapsed = 0.0
		if state != State.ATTACK:
			state = State.WANDER
			if alert_label:
				alert_label.visible = false
	elif state == State.WANDER and distance <= detection:
		state = State.ALERT
		alert_elapsed = 0.0
		_show_alert()
	if state == State.ALERT:
		alert_elapsed += delta
		if distance <= attack_radius and alert_elapsed >= 1.5:
			state = State.ATTACK
		elif distance <= detection and alert_elapsed >= 1.5:
			state = State.CHASE
		elif distance > detection:
			alert_elapsed = 0.0
			state = State.WANDER
	if state == State.WANDER:
		_wander(delta)
	elif state == State.CHASE:
		_chase(delta)
	elif state == State.ATTACK:
		_attack()
		if distance > attack_radius * 1.5:
			state = State.CHASE

func _get_detection_radius() -> float:
	if player.movement_state == "奔跑":
		return detection_radius * 1.6
	if player.movement_state == "潜行":
		return 0.0
	return detection_radius

func _wander(delta: float) -> void:
	if global_position.distance_to(wander_target) < 0.8:
		_choose_wander_target()
	_move_towards(wander_target, move_speed * 0.45, delta)

func _choose_wander_target() -> void:
	wander_target = spawn_point + Vector3(rng.randf_range(-wander_radius, wander_radius), 0.0, rng.randf_range(-wander_radius, wander_radius))

func _chase(delta: float) -> void:
	_show_alert()
	_move_towards(player.global_position, move_speed, delta)

func _move_towards(target: Vector3, speed: float, delta: float) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		global_position += direction.normalized() * speed * delta

func _attack() -> void:
	_show_alert()
	if attack_cooldown <= 0.0:
		GameState.health = maxf(0.0, GameState.health - 10.0)
		attack_cooldown = 1.2

func _show_alert() -> void:
	if alert_label:
		alert_label.visible = true
