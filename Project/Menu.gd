extends Control

const SAVE_PATH := "user://game_save.dat"

@onready var continue_button: Button = $MenuPanel/Buttons/ContinueButton
@onready var settings_panel: PanelContainer = $SettingsPanel

func _ready() -> void:
	continue_button.disabled = not FileAccess.file_exists(SAVE_PATH)
	$MenuPanel/Buttons/NewGameButton.grab_focus()

func _on_new_game_pressed() -> void:
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file:
		save_file.store_string("created=true")
	get_tree().change_scene_to_file("res://Project/Main.tscn")

func _on_continue_pressed() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		get_tree().change_scene_to_file("res://Project/Main.tscn")

func _on_settings_pressed() -> void:
	settings_panel.visible = true
	$SettingsPanel/SettingsBox/CloseButton.grab_focus()

func _on_close_settings_pressed() -> void:
	settings_panel.visible = false
	$MenuPanel/Buttons/SettingsButton.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
