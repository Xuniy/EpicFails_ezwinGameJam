extends Control

## Écran d'accueil : nom du jeu et Play. Le type d'appareil est mémorisé dans GameState :
## un clic (ou une touche) = clavier/souris, le bouton A d'une manette = Xbox.

const NEXT_SCENE := "res://scences/tutorial_screen.tscn"
const TITLE_FONT_SIZE: int = 56
const BUTTON_FONT_SIZE: int = 32

var detected_device: String = ""
var play_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.1, 0.08, 0.05)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 40)
	center.add_child(column)

	var title := Label.new()
	title.text = "The eggceptionnal Chicken Norris"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(title)

	play_button = Button.new()
	play_button.text = "Play"
	play_button.custom_minimum_size = Vector2(240, 70)
	play_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	play_button.pressed.connect(_on_play_pressed)
	column.add_child(play_button)
	play_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		detected_device = GameState.DEVICE_XBOX
	elif event is InputEventKey and (event as InputEventKey).pressed:
		detected_device = GameState.DEVICE_KEYBOARD_MOUSE
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		detected_device = GameState.DEVICE_KEYBOARD_MOUSE


func _on_play_pressed() -> void:
	GameState.input_device = detected_device if detected_device != "" else GameState.DEVICE_KEYBOARD_MOUSE
	GameState.game_over = false
	get_tree().change_scene_to_file(NEXT_SCENE)
