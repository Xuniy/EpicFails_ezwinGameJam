class_name TutorialOverlay
extends CanvasLayer

## Tutoriel interactif en jeu : chaque étape attend que le joueur fasse l'action demandée.
## Ajouté à la partie par GameState.start_game(true).

const DONE_DELAY: float = 1.0
const END_DELAY: float = 3.0

# "only" = "xbox" limite une étape à la manette. "ready" est la dernière étape.
const STEPS := [
	{"id": "move", "pc": "Déplace Chicken Norris avec Z Q S D.", "xbox": "Déplace Chicken Norris avec le stick gauche."},
	{"id": "aim", "pc": "Vise en bougeant la souris.", "xbox": "Vise avec le stick droit."},
	{"id": "shoot", "pc": "Tire avec le clic gauche, maintenu.", "xbox": "Tire avec la gâchette droite RT, maintenue."},
	{"id": "switch", "pc": "Change d'objet avec la molette de la souris.", "xbox": "Change d'objet avec LB ou RB."},
	{"id": "throw", "pc": "Lance un objet : maintiens le clic droit, tire la souris à l'opposé de la cible, puis clic gauche.", "xbox": "Lance un objet : maintiens LT, vise avec le stick droit, puis RT."},
	{"id": "dezoom", "only": "xbox", "pc": "", "xbox": "Dézoome avec la croix directionnelle droite."},
	{"id": "rhythm_open", "pc": "Ouvre le mini-jeu pour fumer avec la touche A.", "xbox": "Ouvre le mini-jeu pour fumer avec la croix directionnelle haut."},
	{"id": "rhythm_hit", "pc": "Appuie sur 1, 2, 3 ou 4 au bon moment.", "xbox": "Appuie sur Y, X, A ou B au bon moment."},
	{"id": "ready", "pc": "Tu es prêt ! Protège le poulailler.", "xbox": "Tu es prêt ! Protège le poulailler."},
]

# Référence untyped volontairement : les méthodes du joueur et du HUD sont appelées dynamiquement.
var player
var joint
var rhythm
var weapon
var is_xbox: bool = false
var active_steps: Array = []
var step: int = 0
var done_timer: float = 0.0
var previous_joint: float = 0.0
var step_position := Vector2.ZERO
var step_selected: int = 0
var step_items: int = 0
var step_mouse := Vector2.ZERO
var label: Label
var counter: Label


func _ready() -> void:
	var scene := get_tree().current_scene
	player = scene.find_child("Player", true, false)
	if player == null:
		queue_free()
		return

	joint = scene.find_child("JointBar", true, false)
	rhythm = _find_rhythm(scene)
	weapon = player.get_node("Weapon")
	is_xbox = GameState.input_device == GameState.DEVICE_XBOX

	for entry in STEPS:
		if not entry.has("only") or (entry["only"] == "xbox") == is_xbox:
			active_steps.append(entry)

	# Quelques objets pour s'entraîner au lancer.
	for item in ["grenade", "grenade", "tp"]:
		player.collect_item(item)

	_build_ui()
	_begin_step()
	previous_joint = _joint_amount()


func _process(delta: float) -> void:
	if done_timer > 0.0:
		done_timer -= delta
		if done_timer <= 0.0:
			step += 1
			if step >= active_steps.size():
				queue_free()
				return
			_begin_step()
	elif _is_step_done(active_steps[step]["id"]):
		label.text = "✔ " + _instruction(active_steps[step])
		done_timer = END_DELAY if active_steps[step]["id"] == "ready" else DONE_DELAY
	previous_joint = _joint_amount()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -450.0
	panel.offset_right = 450.0
	panel.offset_top = 16.0
	add_child(panel)

	var column := VBoxContainer.new()
	panel.add_child(column)

	counter = Label.new()
	counter.add_theme_font_size_override("font_size", 18)
	column.add_child(counter)

	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(860, 0)
	label.add_theme_font_size_override("font_size", 28)
	column.add_child(label)


func _begin_step() -> void:
	var entry: Dictionary = active_steps[step]
	label.text = _instruction(entry)
	counter.text = "Étape %d / %d" % [step + 1, active_steps.size()]
	step_position = player.global_position
	step_selected = player.selected_index
	step_items = _item_total()
	step_mouse = get_viewport().get_mouse_position()


func _instruction(entry: Dictionary) -> String:
	return entry["xbox"] if is_xbox else entry["pc"]


func _is_step_done(id: String) -> bool:
	match id:
		"move":
			return player.global_position.distance_to(step_position) > 80.0
		"aim":
			return get_viewport().get_mouse_position().distance_to(step_mouse) > 30.0 \
				or Input.get_vector("sr_gauche", "sr_droite", "sr_haut", "sr_bas").length() > 0.5
		"shoot":
			return weapon.cooldown > 0.01
		"switch":
			return player.selected_index != step_selected
		"throw":
			return _item_total() < step_items
		"dezoom":
			return Input.is_action_pressed("dezoom")
		"rhythm_open":
			return rhythm != null and rhythm.active
		"rhythm_hit":
			return rhythm != null and rhythm.active and _joint_amount() - previous_joint > 0.01
		"ready":
			return true
	return false


func _item_total() -> int:
	var total := 0
	for count in player.items.values():
		total += count
	return total


func _joint_amount() -> float:
	return joint.amount if joint else 1.0


func _find_rhythm(node: Node) -> Node:
	if node is RhythmGame:
		return node
	for child in node.get_children():
		var found := _find_rhythm(child)
		if found:
			return found
	return null
