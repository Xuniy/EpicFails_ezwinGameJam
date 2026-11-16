extends Node

## État de session partagé entre les scènes : type d'appareil, fin de partie et
## lancement de la partie (avec le tutoriel interactif au premier démarrage).

const DEVICE_XBOX := "xbox"
const DEVICE_KEYBOARD_MOUSE := "clavier_souris"
const WORLD_SCENE := "res://scences/world_test.tscn"

var input_device: String = DEVICE_KEYBOARD_MOUSE
var game_over: bool = false
var show_tutorial: bool = false
var pause_menu: CanvasLayer


func _ready() -> void:
	# Menu pause unique, enfant de l'autoload : il reste actif d'une scène à l'autre.
	pause_menu = preload("res://scripts/pause_menu.gd").new()
	add_child(pause_menu)


func start_game(with_tutorial: bool) -> void:
	game_over = false
	show_tutorial = with_tutorial
	get_tree().scene_changed.connect(_on_scene_changed, CONNECT_ONE_SHOT)
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_scene_changed() -> void:
	if show_tutorial:
		show_tutorial = false
		get_tree().current_scene.call_deferred("add_child", TutorialOverlay.new())
