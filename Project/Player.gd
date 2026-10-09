extends CharacterBody3D

@export var move_speed := 6.0
@export var walk_speed := 5.5
@export var run_speed := 8.5
@export var stealth_speed := 2.5
@export var play_area := Vector2(155.0, 115.0)
@export var stamina_drain := 18.0
@export var stamina_recovery := 12.0
@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var facing: Node3D = $Facing
var movement_state := "行走"

func _physics_process(_delta: float) -> void:
	var keyboard_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var movement := Vector3(keyboard_input.x, 0.0, keyboard_input.y)
	var is_running := Input.is_action_pressed("sprint") and movement.length_squared() > 0.01 and GameState.stamina > 0.0
	var is_stealth := Input.is_action_pressed("stealth") and not is_running
	var current_speed := walk_speed
	if is_running:
		movement_state = "奔跑"
		current_speed = run_speed
		GameState.stamina = maxf(0.0, GameState.stamina - stamina_drain * _delta)
	else:
		movement_state = "潜行" if is_stealth else "行走"
		current_speed = stealth_speed if is_stealth else walk_speed
		GameState.stamina = minf(100.0, GameState.stamina + stamina_recovery * _delta)
	velocity.x = movement.x * current_speed
	velocity.z = movement.z * current_speed
	velocity.y = 0.0
	move_and_slide()
	global_position.x = clampf(global_position.x, -play_area.x, play_area.x)
	global_position.z = clampf(global_position.z, -play_area.y, play_area.y)
	_update_facing()

func _update_facing() -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length_squared() > 0.04:
		facing.rotation.y = atan2(stick.x, stick.y)
		return
	if camera == null:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	if abs(ray_direction.y) < 0.001:
		return
	var distance := (global_position.y - ray_origin.y) / ray_direction.y
	var direction := ray_origin + ray_direction * distance - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.04:
		facing.rotation.y = atan2(direction.x, direction.z)
