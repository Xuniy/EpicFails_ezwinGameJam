extends Control

## Tutoriel en jeu, affiché entre l'écran d'accueil et la partie.
## Les pages sont choisies selon l'appareil mémorisé dans GameState.input_device.

const GAME_SCENE := "res://scences/world_test.tscn"

const PAGES_PC := [
	{"title": "Bienvenue", "text": "Tu incarnes Chicken Norris, une poule armée qui défend son poulailler.\nSi ta vie ou celle du poulailler tombe à 0, la partie est perdue."},
	{"title": "Déplacement et tir", "text": "Déplacement : Z Q S D.\nVise en bougeant la souris : l'arme suit le curseur.\nTir : clic gauche, maintenu pour tirer en continu."},
	{"title": "Changer d'objet", "text": "Les trois objets sont dans la barre en bas au centre : eggrenade, eggder pearl et egg bomba.\nMolette vers le haut : objet précédent. Molette vers le bas : objet suivant."},
	{"title": "Lancer un objet", "text": "Maintiens le clic droit : le zoom s'adapte et un élastique apparaît.\nTire la souris dans le sens opposé à la cible : plus la traction est longue, plus l'objet va loin.\nClic gauche pour lancer. Relâcher le clic droit sans valider annule."},
	{"title": "Les objets", "text": "eggrenade : explose à sa chute et blesse les ennemis proches.\neggder pearl : te téléporte au point visé, si la place est libre.\negg bomba : explose après un court délai et élimine les ennemis de son rayon.\nMarche sur un objet au sol pour le récupérer."},
	{"title": "Fumer le joint", "text": "Le joint se consume en 45 secondes. Vide, il te fait perdre 5 points de vie toutes les 2 secondes.\nTouche A : ouvre ou ferme le mini-jeu de rythme.\nTouches 1, 2, 3, 4 : les quatre voies. Une bonne touche ajoute 5 secondes au joint."},
	{"title": "Les barres et la boussole", "text": "En haut à gauche : le joint. Sous lui : ta vie et celle du poulailler.\nSi le poulailler sort de l'écran, une flèche sur le bord indique sa direction."},
	{"title": "Fin de partie", "text": "Chicken Norris mort ou poulailler détruit : l'écran de fin apparaît.\nPlay again relance la partie."},
]

const PAGES_XBOX := [
	{"title": "Bienvenue", "text": "Tu incarnes Chicken Norris, une poule armée qui défend son poulailler.\nSi ta vie ou celle du poulailler tombe à 0, la partie est perdue."},
	{"title": "Déplacement et tir", "text": "Déplacement : stick gauche.\nVise : stick droit, l'arme regarde dans sa direction.\nTir : gâchette droite (RT), maintenue pour tirer en continu."},
	{"title": "Changer d'objet", "text": "Les trois objets sont dans la barre en bas au centre : eggrenade, eggder pearl et egg bomba.\nLB : objet précédent. RB : objet suivant."},
	{"title": "Lancer un objet", "text": "Maintiens la gâchette gauche (LT) : le zoom s'adapte et un arc apparaît.\nChoisis la direction et la distance avec le stick droit.\nRT pour lancer. Relâcher LT sans valider annule."},
	{"title": "Dézoomer", "text": "Croix directionnelle droite : dézoome la caméra pour voir plus loin."},
	{"title": "Les objets", "text": "eggrenade : explose à sa chute et blesse les ennemis proches.\neggder pearl : te téléporte au point visé, si la place est libre.\negg bomba : explose après un court délai et élimine les ennemis de son rayon.\nMarche sur un objet au sol pour le récupérer."},
	{"title": "Fumer le joint", "text": "Le joint se consume en 45 secondes. Vide, il te fait perdre 5 points de vie toutes les 2 secondes.\nCroix directionnelle haut : ouvre ou ferme le mini-jeu de rythme.\nY, X, A, B : les quatre voies. Une bonne touche ajoute 5 secondes au joint."},
	{"title": "Les barres et la boussole", "text": "En haut à gauche : le joint. Sous lui : ta vie et celle du poulailler.\nSi le poulailler sort de l'écran, une flèche sur le bord indique sa direction."},
	{"title": "Fin de partie", "text": "Chicken Norris mort ou poulailler détruit : l'écran de fin apparaît.\nPlay again relance la partie."},
]

var pages: Array = []
var index: int = 0
var title_label: Label
var body_label: Label
var counter_label: Label
var prev_button: Button
var next_button: Button


func _ready() -> void:
	pages = PAGES_XBOX if GameState.input_device == GameState.DEVICE_XBOX else PAGES_PC
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.1, 0.08, 0.05)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 28)
	center.add_child(column)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	column.add_child(title_label)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(900, 0)
	body_label.add_theme_font_size_override("font_size", 28)
	column.add_child(body_label)

	counter_label = Label.new()
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(counter_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 30)
	column.add_child(buttons)

	prev_button = _make_button("Précédent", _on_prev_pressed)
	buttons.add_child(prev_button)
	next_button = _make_button("Suivant", _on_next_pressed)
	buttons.add_child(next_button)
	buttons.add_child(_make_button("Passer", _start_game))

	_show_page()


func _make_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(220, 60)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(callback)
	return button


func _show_page() -> void:
	var page: Dictionary = pages[index]
	title_label.text = page["title"]
	body_label.text = page["text"]
	counter_label.text = "%d / %d" % [index + 1, pages.size()]
	prev_button.disabled = index == 0
	next_button.text = "Commencer" if index == pages.size() - 1 else "Suivant"
	next_button.grab_focus()


func _on_prev_pressed() -> void:
	if index > 0:
		index -= 1
		_show_page()


func _on_next_pressed() -> void:
	if index == pages.size() - 1:
		_start_game()
	else:
		index += 1
		_show_page()


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
