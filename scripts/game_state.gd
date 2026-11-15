extends Node

## État de session partagé entre les scènes : type d'appareil, fin de partie et
## lancement de la partie (avec le tutoriel interactif au premier démarrage).

const DEVICE_XBOX := "xbox"
const DEVICE_KEYBOARD_MOUSE := "clavier_souris"
const WORLD_SCENE := "res://scences/world_test.tscn"

var input_device: String = DEVICE_KEYBOARD_MOUSE
var game_over: bool = false
var show_tutorial: bool = false


func _ready() -> void:
	get_tree().scene_changed.connect(_add_markers)


# Flèches hors cadre (ennemis, objets au sol) : ajoutées à chaque scène de jeu, rechargements compris.
func _add_markers() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.find_child("Player", true, false) == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	var markers := OffscreenMarkers.new()
	markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(markers)
	scene.call_deferred("add_child", layer)


func start_game(with_tutorial: bool) -> void:
	game_over = false
	show_tutorial = with_tutorial
	get_tree().scene_changed.connect(_on_scene_changed, CONNECT_ONE_SHOT)
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_scene_changed() -> void:
	if show_tutorial:
		show_tutorial = false
		get_tree().current_scene.call_deferred("add_child", TutorialOverlay.new())
