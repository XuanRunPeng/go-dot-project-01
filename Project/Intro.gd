extends Control

const STORY_LINES := [
	"黑云吞噬天空的那一天，城市的灯一盏接一盏熄灭。",
	"你从地下实验室的废墟中醒来。",
	"这里曾是“普罗米修斯计划”的核心设施，而你是计划的工程师。",
	"地面上，丧尸正在废墟之间游荡。",
	"城市的三个基站已经停止运转，庇护所外的道路也被黑暗切断。",
	"你知道重启城市的方法，也知道留给你的时间正在减少。",
	"在接下来的二十一天里，寻找资源，修复基站，追查实验室留下的真相。",
	"但现在，你只有一个任务。",
	"活下去。"
]

@onready var story_container: VBoxContainer = $Story
@onready var prompt_label: Label = $Prompt
var line_index := 0
var can_continue := false
var is_transitioning := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	prompt_label.modulate.a = 0.0
	_show_next_line()

func _show_next_line() -> void:
	if line_index >= STORY_LINES.size():
		_enable_continue()
		return
	var line_label := Label.new()
	line_label.text = STORY_LINES[line_index]
	line_label.custom_minimum_size = Vector2(1120, 42)
	line_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94, 1))
	line_label.add_theme_font_size_override("font_size", 27)
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line_label.modulate.a = 0.0
	story_container.add_child(line_label)
	var tween := create_tween()
	tween.tween_property(line_label, "modulate:a", 1.0, 0.75)
	tween.tween_interval(1.25)
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
	fade_tween.tween_callback(func(): get_tree().change_scene_to_file("res://Project/Main.tscn"))
