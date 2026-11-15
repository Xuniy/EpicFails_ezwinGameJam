extends CanvasLayer

const TITLE_SCENE := "res://scences/title_screen.tscn"

@export_range(1.0, 2.0, 0.1) var effect_strength: float = 1.8

@onready var effect: ShaderMaterial = $PerfectEffect/Distortion.material
@onready var return_button: Button = $Root/Center/Column/ReturnButton

var _elapsed: float = 0.0
var _returning: bool = false


func _ready() -> void:
	var world := get_tree().current_scene
	var player_effect := world.get_node_or_null("Player/PerfectEffect") as CanvasLayer
	if player_effect != null:
		player_effect.hide()
	# Un flash d’explosion ne doit pas rester blanc lorsque le monde est figé.
	for flash in world.find_children("Flash", "CanvasLayer", true, false):
		flash.hide()
	GameState.game_over = true
	get_tree().paused = true
	return_button.pressed.connect(_return_to_title)
	return_button.grab_focus()


func _process(delta: float) -> void:
	_elapsed += delta
	effect.set_shader_parameter("effect_time", _elapsed)
	effect.set_shader_parameter("intensity", effect_strength * minf(1.0, _elapsed / 0.4))


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		get_viewport().set_input_as_handled()
		_return_to_title()


func _return_to_title() -> void:
	if _returning:
		return
	_returning = true
	GameState.game_over = false
	GameState.show_tutorial = false
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
