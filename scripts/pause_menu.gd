class_name PauseMenu
extends CanvasLayer

## Menu pause : Échap / P au clavier, bouton Menu (☰, à droite du logo Xbox) à la manette.
## Créé une seule fois par GameState, il survit aux changements de scène.
## Il ne s'ouvre que pendant la partie : jamais si le jeu est déjà figé par autre chose
## (écran titre, tutoriel, dialogue de vague, game over, victoire).

const TITLE_SCENE := "res://scences/title_screen.tscn"
const TITLE_FONT_SIZE: int = 56
const BUTTON_FONT_SIZE: int = 32

var is_open: bool = false
var _resume_button: Button
var _buttons: Array[Button] = []
var _stick_ready: bool = true   # le stick doit revenir au centre avant un nouveau pas


func _ready() -> void:
	layer = 90                                   # sous l'écran de fin (100)
	process_mode = Node.PROCESS_MODE_ALWAYS      # doit fonctionner pendant la pause
	_build_ui()
	hide()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)

	var title := Label.new()
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(title)

	_resume_button = _add_button(column, "Reprendre", close)
	_add_button(column, "Retour au menu", _return_to_title)
	if not OS.has_feature("web"):                # quitter n'a pas de sens dans un navigateur
		_add_button(column, "Quitter le jeu", func() -> void: get_tree().quit())

	var hint := Label.new()
	hint.text = "Échap / P / Menu : reprendre"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.6)
	column.add_child(hint)


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(340, 64)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.pressed.connect(action)
	parent.add_child(button)
	_buttons.append(button)
	return button


func _input(event: InputEvent) -> void:
	if _is_pause_toggle(event):
		get_viewport().set_input_as_handled()
		if is_open:
			close()
		elif _can_open():
			open()
	elif is_open:
		_handle_gamepad(event)


## Navigation manette gérée ici directement, sans dépendre des actions ui_* du projet :
## croix / stick gauche = changer de bouton, A = valider, B = reprendre.
func _handle_gamepad(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				get_viewport().set_input_as_handled()
				var focused := _focused_index()
				if focused >= 0:
					_buttons[focused].pressed.emit()
				elif not _buttons.is_empty():
					_buttons[0].grab_focus()     # focus perdu (clic souris) : on le remet
			JOY_BUTTON_B:
				get_viewport().set_input_as_handled()
				close()
			JOY_BUTTON_DPAD_UP:
				get_viewport().set_input_as_handled()
				_move_focus(-1)
			JOY_BUTTON_DPAD_DOWN:
				get_viewport().set_input_as_handled()
				_move_focus(1)
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		get_viewport().set_input_as_handled()
		if absf(event.axis_value) < 0.3:
			_stick_ready = true
		elif _stick_ready and absf(event.axis_value) > 0.6:
			_stick_ready = false
			_move_focus(1 if event.axis_value > 0.0 else -1)


func _focused_index() -> int:
	for i in _buttons.size():
		if _buttons[i].has_focus():
			return i
	return -1


func _move_focus(step: int) -> void:
	if _buttons.is_empty():
		return
	var current := maxi(_focused_index(), 0)
	_buttons[posmod(current + step, _buttons.size())].grab_focus()


func _is_pause_toggle(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo \
			and event.physical_keycode in [KEY_ESCAPE, KEY_P]
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index == JOY_BUTTON_START
	return false


func _can_open() -> bool:
	var tree := get_tree()
	# Déjà figé par un autre écran, partie terminée, ou pas de scène de jeu : on ne fait rien.
	return not tree.paused and not GameState.game_over and tree.current_scene != null


func open() -> void:
	if is_open:
		return
	is_open = true
	show()
	get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	get_tree().paused = false


func _return_to_title() -> void:
	is_open = false
	hide()
	GameState.game_over = false
	GameState.show_tutorial = false
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
