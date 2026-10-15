# 2D 玩家控制器：处理 WASD 移动、奔跑、潜行和体力。
# walk_speed：普通行走速度；run_speed：按住 Shift 时的速度。
# stealth_speed：按住 Ctrl 时的速度；play_area：玩家可移动的地图边界。
# stamina_drain：奔跑消耗速率；stamina_recovery：停止奔跑后的恢复速率。
# movement_state：向敌人 AI 和 HUD 暴露“行走、奔跑、潜行”状态。
# _physics_process：读取输入、计算速度、移动角色并限制地图边界。
extends CharacterBody2D

@export var walk_speed := 90.0
@export var run_speed := 145.0
@export var stealth_speed := 42.0
@export var play_area := Vector2(155.0, 115.0)
@export var stamina_drain := 18.0
@export var stamina_recovery := 12.0
var movement_state := "行走"

func _physics_process(delta: float) -> void:
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
	position.x = clampf(position.x, -play_area.x, play_area.x)
	position.y = clampf(position.y, -play_area.y, play_area.y)
