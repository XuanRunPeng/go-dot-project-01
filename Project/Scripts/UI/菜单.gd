# 主菜单：提供新游戏、继续游戏、设置和退出入口。
# SETTINGS_PATH：保存音量配置；DEFAULT_VOLUME：首次运行的默认音量值。
# _ready：初始化存档按钮和音量界面；新游戏与继续游戏进入不同流程。
# _on_settings_pressed/_on_close_settings_pressed：显示或隐藏设置面板。
# _on_volume_changed：更新音量并写入配置；左右按钮复用滑块限制为 1 到 10。
# _has_valid_save：检查 GameState 存档，决定继续按钮是否可用。
extends Control

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 10

@onready var continue_button: Button = $菜单面板/按钮组/继续游戏按钮
@onready var settings_panel: PanelContainer = $设置面板
@onready var volume_slider: HSlider = $设置面板/设置内容/音量行/音量滑块
@onready var volume_value: Label = $设置面板/设置内容/音量行/音量数值

func _ready() -> void:
	continue_button.disabled = not _has_valid_save()
	volume_slider.value = _load_volume()
	_update_volume(volume_slider.value)
	$菜单面板/按钮组/新游戏按钮.grab_focus()

func _on_new_game_pressed() -> void:
	GameState.start_new_game()
	if GameState.save_game():
		get_tree().change_scene_to_file("res://Project/Scenes/UI/开场介绍.tscn")

func _on_continue_pressed() -> void:
	if GameState.has_valid_save():
		get_tree().change_scene_to_file("res://Project/Scenes/2D/主场景2D.tscn")

func _on_settings_pressed() -> void:
	settings_panel.visible = true
	$设置面板/设置内容/返回按钮.grab_focus()

func _on_close_settings_pressed() -> void:
	settings_panel.visible = false
	$菜单面板/按钮组/设置按钮.grab_focus()

func _on_volume_changed(value: float) -> void:
	_update_volume(value)
	var config := ConfigFile.new()
	config.set_value("audio", "volume", int(value))
	config.save(SETTINGS_PATH)

func _on_volume_decreased() -> void:
	volume_slider.value = maxf(1.0, volume_slider.value - 1.0)

func _on_volume_increased() -> void:
	volume_slider.value = minf(10.0, volume_slider.value + 1.0)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _load_volume() -> float:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		return clampf(float(config.get_value("audio", "volume", DEFAULT_VOLUME)), 1.0, 10.0)
	return DEFAULT_VOLUME

func _update_volume(value: float) -> void:
	var volume := clampi(int(value), 1, 10)
	volume_value.text = str(volume) + " / 10"
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(float(volume) / 10.0))

func _has_valid_save() -> bool:
	return GameState.has_valid_save()
