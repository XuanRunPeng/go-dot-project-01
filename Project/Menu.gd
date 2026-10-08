extends Control

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 10

@onready var continue_button: Button = $MenuPanel/Buttons/ContinueButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/SettingsBox/VolumeRow/VolumeSlider
@onready var volume_value: Label = $SettingsPanel/SettingsBox/VolumeRow/VolumeValue

func _ready() -> void:
	continue_button.disabled = not _has_valid_save()
	volume_slider.value = _load_volume()
	_update_volume(volume_slider.value)
	$MenuPanel/Buttons/NewGameButton.grab_focus()

func _on_new_game_pressed() -> void:
	GameState.start_new_game()
	if GameState.save_game():
		get_tree().change_scene_to_file("res://Project/Intro.tscn")

func _on_continue_pressed() -> void:
	if GameState.has_valid_save():
		get_tree().change_scene_to_file("res://Project/Main.tscn")

func _on_settings_pressed() -> void:
	settings_panel.visible = true
	$SettingsPanel/SettingsBox/CloseButton.grab_focus()

func _on_close_settings_pressed() -> void:
	settings_panel.visible = false
	$MenuPanel/Buttons/SettingsButton.grab_focus()

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
