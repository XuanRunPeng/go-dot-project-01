# 开场介绍过场：逐句淡入剧情并切入 2D 游戏场景。
# STORY_LINES：只保留玩家开始行动前必须知道的五条背景信息。
# line_index：当前剧情序号；can_continue：是否已经显示完全部剧情。
# skip_button 和底部提示都调用 _continue_to_game，确保转场逻辑只有一份。
# _show_next_line：创建并淡入下一句话；_enable_continue：开启闪烁继续提示。
extends Control

const STORY_LINES := [
	"黑云吞噬天空，城市的灯一盏接一盏熄灭。",
	"你从地下实验室的废墟中醒来。你是“普罗米修斯计划”的工程师。",
	"三个城市基站已经停止运转，地面只剩下废墟和游荡的丧尸。",
	"你知道重启基站的方法，但只剩二十一天寻找资源、修复设备。",
	"现在，先离开实验室。活下去。"
]

@onready var story_container: VBoxContainer = $剧情文本
@onready var prompt_label: Label = $继续提示
@onready var skip_button: Button = $跳过按钮
var line_index := 0
var can_continue := false
var is_transitioning := false
var line_labels: Array[Label] = []

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	prompt_label.modulate.a = 0.0
	skip_button.pressed.connect(_continue_to_game)
	_create_story_lines()
	_show_next_line()

func _create_story_lines() -> void:
	# 预先创建所有固定行位，避免新增节点时文本位置发生变化。
	for story_line in STORY_LINES:
		var line_label := Label.new()
		line_label.text = story_line
		line_label.custom_minimum_size = Vector2(1120, 54)
		line_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94, 1))
		line_label.add_theme_font_size_override("font_size", 26)
		line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line_label.modulate.a = 0.0
		story_container.add_child(line_label)
		line_labels.append(line_label)

func _show_next_line() -> void:
	if line_index >= STORY_LINES.size():
		_enable_continue()
		return

	var line_label := line_labels[line_index]
	var tween := create_tween()
	# 当前句淡入后保留，下一句只在当前句完成后从固定的下一行出现。
	tween.tween_property(line_label, "modulate:a", 1.0, 0.65)
	tween.tween_interval(1.45 if line_index < STORY_LINES.size() - 1 else 2.2)
	tween.tween_callback(func():
		line_index += 1
		_show_next_line()
	)

func _enable_continue() -> void:
	can_continue = true
	prompt_label.text = "点击任意位置或按任意键继续"
	var prompt_tween := create_tween().set_loops()
	prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.55)
	prompt_tween.tween_interval(0.45)
	prompt_tween.tween_property(prompt_label, "modulate:a", 0.25, 0.55)

func _input(event: InputEvent) -> void:
	if not can_continue or is_transitioning:
		return
	if event is InputEventKey and event.pressed:
		_continue_to_game()
	elif event is InputEventMouseButton and event.pressed:
		_continue_to_game()
	elif event is InputEventJoypadButton and event.pressed:
		_continue_to_game()

func _continue_to_game() -> void:
	is_transitioning = true
	can_continue = false
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.7)
	fade_tween.tween_callback(func(): get_tree().change_scene_to_file("res://Project/Scenes/2D/主场景2D.tscn"))
