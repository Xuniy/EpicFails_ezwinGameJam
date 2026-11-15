class_name EndScreen
extends CanvasLayer

## Écran de fin réutilisable : affiche la raison, met le jeu en pause et propose Play again.
## Appel : EndScreen.show_end(get_tree(), "texte").

const TITLE_FONT_SIZE: int = 48
const BUTTON_FONT_SIZE: int = 32

var message: String = ""


static func show_end(tree: SceneTree, text: String) -> void:
	if GameState.game_over:
		return
	GameState.game_over = true
	var screen := EndScreen.new()
	screen.message = text
	tree.current_scene.add_child(screen)
	tree.paused = true


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 40)
	center.add_child(column)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(label)

	var again := Button.new()
	again.text = "Play again"
	again.custom_minimum_size = Vector2(280, 70)
	again.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	again.pressed.connect(_on_play_again)
	column.add_child(again)
	again.grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		get_viewport().set_input_as_handled()
		_on_play_again()


func _on_play_again() -> void:
	GameState.game_over = false
	get_tree().paused = false
	get_tree().reload_current_scene()
