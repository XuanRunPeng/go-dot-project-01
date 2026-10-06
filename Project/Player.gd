extends CharacterBody3D

@export var move_speed := 6.0
@export var play_area := Vector2(19.0, 19.0)
@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var facing: Node3D = $Facing

func _physics_process(_delta: float) -> void:
	var keyboard_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var movement := Vector3(keyboard_input.x, 0.0, keyboard_input.y)
	velocity.x = movement.x * move_speed
	velocity.z = movement.z * move_speed
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
