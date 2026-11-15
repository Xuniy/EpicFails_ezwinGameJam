class_name TutorialOverlay
extends CanvasLayer

## Tutoriel scénarisé en jeu, guidé par Maître Coq. Pas de coroutines : une file d'entrées
## traitée dans _process, qui s'arrête proprement si la scène change.
## Une bulle ne bloque pas le jeu, sauf les répliques d'introduction. Une étape déjà
## accomplie est sautée, bulle comprise.

const ENEMY_SCENE := preload("res://scences/ennemy.tscn")
const ICON_MOUSE := preload("res://assets/tutoriel/mouse.png")
const ICON_RT := preload("res://assets/tutoriel/xbox_rt.png")
const ICON_LT := preload("res://assets/tutoriel/xbox_lt.png")
const ICON_LB := preload("res://assets/tutoriel/xbox_lb.png")
const SPEAKER := "Maître Coq"
const ICON_SIZE: float = 42.0
const BUBBLE_TIME: float = 8.0
# Joint figé pendant le tutoriel : durée énorme = décroissance quasi nulle.
const FROZEN_DURATION: float = 1.0e9
# Centre de l'enceinte du poulailler (relatif à son origine) et rayon à garder libre d'ennemis.
const POULAILLER_CENTER := Vector2(-80.0, 140.0)
const SAFE_RADIUS: float = 560.0
# Étape du joint validée quand le joint est presque plein (le mini-jeu se ferme à 100 %).
const JOINT_DONE_AMOUNT: float = 0.95

# Référence untyped volontairement : les méthodes du joueur et du HUD sont appelées dynamiquement.
var player
var joint
var poulailler: Node2D
var enemies_root: Node
var is_xbox: bool = false
var joint_duration: float = 45.0
var groups: Dictionary = {}
var queue: Array = []
var current: Dictionary = {}
var bubble_timer: float = 0.0

var mission_label: Label
var mission_icon: TextureRect
var speaker_label: Label
var dialogue_label: Label
var dialogue_panel: PanelContainer


func _ready() -> void:
	var scene := get_tree().current_scene
	player = scene.find_child("Player", true, false)
	if player == null:
		queue_free()
		return

	joint = scene.find_child("JointBar", true, false)
	if joint:
		joint_duration = joint.duration
		joint.duration = FROZEN_DURATION
		joint.amount = 1.0
	poulailler = scene.get_node_or_null("poulailler") as Node2D
	enemies_root = scene.get_node_or_null("Enemies")
	if enemies_root == null:
		enemies_root = scene
	is_xbox = GameState.input_device == GameState.DEVICE_XBOX

	_build_ui()
	_set_spawner(false)
	queue = _build_script()


func _build_ui() -> void:
	var mission := PanelContainer.new()
	mission.anchor_left = 0.5
	mission.anchor_right = 0.5
	mission.offset_left = -450.0
	mission.offset_right = 450.0
	mission.offset_top = 16.0
	add_child(mission)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	mission.add_child(row)

	mission_icon = TextureRect.new()
	mission_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	mission_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mission_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mission_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mission_icon.visible = false
	row.add_child(mission_icon)

	mission_label = Label.new()
	mission_label.add_theme_font_size_override("font_size", 26)
	row.add_child(mission_label)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.anchor_left = 0.5
	dialogue_panel.anchor_right = 0.5
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.offset_left = -480.0
	dialogue_panel.offset_right = 480.0
	dialogue_panel.offset_top = -210.0
	dialogue_panel.offset_bottom = -30.0
	dialogue_panel.visible = false
	add_child(dialogue_panel)

	var column := VBoxContainer.new()
	dialogue_panel.add_child(column)

	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 26)
	speaker_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	speaker_label.text = SPEAKER
	column.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size = Vector2(900, 0)
	dialogue_label.add_theme_font_size_override("font_size", 28)
	column.add_child(dialogue_label)

	var hint := Label.new()
	hint.text = "Entrée, A ou clic gauche pour continuer"
	hint.add_theme_font_size_override("font_size", 18)
	column.add_child(hint)


# Scénario. "say" = réplique ; "do" = action ; "objective" = étape (sautée si déjà accomplie).
func _build_script() -> Array:
	return [
		{"type": "say", "blocking": true, "text": "Chicken Norris ! Des renards et des fermiers attaquent notre poulailler."},
		{"type": "say", "blocking": true, "text": "Ton but : le protéger. Si ta vie ou celle du poulailler tombe à zéro, c'est perdu."},
		{"type": "say", "blocking": true, "text": "Commence par t'entraîner. Une cible apparaît devant toi."},
		{"type": "do", "run": Callable(self, "_wave_target")},
		{"type": "objective", "kind": "kill", "group": "target",
			"pc": "Tire sur la cible devant toi (clic gauche).", "xbox": "Tire sur la cible devant toi (RT).",
			"icon_pc": ICON_MOUSE, "icon_xbox": ICON_RT, "say": ""},
		{"type": "objective", "kind": "pick", "item": "tp",
			"pc": "Ramasse l'eggder pearl.", "xbox": "Ramasse l'eggder pearl.",
			"say": "Elle a laissé une eggder pearl : ramasse-la en marchant dessus."},
		{"type": "objective", "kind": "switch",
			"pc": "Change d'objet : molette de la souris.", "xbox": "Change d'objet : LB ou RB.",
			"icon_pc": ICON_MOUSE, "icon_xbox": ICON_LB,
			"say": "Change d'objet avec la molette, ou avec LB et RB à la manette."},
		{"type": "objective", "kind": "use", "item": "tp",
			"pc": "Lance l'eggder pearl : clic droit maintenu, puis clic gauche.",
			"xbox": "Lance l'eggder pearl : LT maintenu, puis RT.",
			"icon_pc": ICON_MOUSE, "icon_xbox": ICON_LT,
			"say": "L'eggder pearl te téléporte au point visé, si la place est libre."},
		{"type": "do", "run": Callable(self, "_wave_second")},
		{"type": "objective", "kind": "kill", "group": "second",
			"pc": "Tue le second ennemi (clic gauche).", "xbox": "Tue le second ennemi (RT).",
			"icon_pc": ICON_MOUSE, "icon_xbox": ICON_RT,
			"say": "Un second ennemi approche."},
		{"type": "objective", "kind": "pick", "item": "grenade",
			"pc": "Ramasse la grenade.", "xbox": "Ramasse la grenade.",
			"say": "Il a laissé une grenade. Elle explose à sa chute et blesse les ennemis proches."},
		{"type": "do", "run": Callable(self, "_wave_small")},
		{"type": "objective", "kind": "use_kill", "item": "grenade", "group": "small",
			"pc": "Lance la grenade sur le petit groupe : clic droit, puis clic gauche.",
			"xbox": "Lance la grenade sur le petit groupe : LT, puis RT.",
			"icon_pc": ICON_MOUSE, "icon_xbox": ICON_LT,
			"say": "Un petit groupe approche. Lance la grenade au milieu."},
		{"type": "objective", "kind": "pick", "item": "nuke",
			"pc": "Ramasse l'egg bomba.", "xbox": "Ramasse l'egg bomba.",
			"say": "Un ennemi a laissé une egg bomba : elle élimine tous les ennemis de son rayon."},
		{"type": "do", "run": Callable(self, "_wave_big")},
		{"type": "objective", "kind": "use_kill", "item": "nuke", "group": "big",
			"pc": "Lance l'egg bomba sur le gros groupe : clic droit, puis clic gauche.",
			"xbox": "Lance l'egg bomba sur le gros groupe : LT, puis RT.",
			"icon_pc": ICON_MOUSE, "icon_xbox": ICON_LT,
			"say": "Un gros groupe arrive. Lance l'egg bomba au centre."},
		{"type": "do", "run": Callable(self, "_joint_setup")},
		{"type": "objective", "kind": "joint",
			"pc": "Fume : touche A, puis 1, 2, 3 ou 4 au bon moment.",
			"xbox": "Fume : croix haut, puis Y, X, A ou B au bon moment.",
			"say": "Ton joint est presque vide : vide, il te fait perdre de la vie. Chaque bonne touche ajoute 5 secondes."},
		{"type": "say", "blocking": true, "text": "Parfait. Tu es prêt. Protège le poulailler !"},
		{"type": "do", "run": Callable(self, "_finish")},
		{"type": "objective", "kind": "always",
			"pc": "Protège le poulailler.", "xbox": "Protège le poulailler."},
	]


func _process(delta: float) -> void:
	if bubble_timer > 0.0:
		bubble_timer -= delta
		if bubble_timer <= 0.0:
			dialogue_panel.visible = false

	if not current.is_empty():
		if _is_done(current):
			current = {}
		return
	_next()


# Traite la file jusqu'à la prochaine étape active ou réplique bloquante.
func _next() -> void:
	while not queue.is_empty():
		var entry: Dictionary = queue.pop_front()
		match entry["type"]:
			"do":
				entry["run"].call()
			"say":
				_show_bubble(entry["text"])
				if entry.get("blocking", false):
					current = {"type": "bubble_wait"}
					return
			"objective":
				if _is_done(entry):
					continue
				_start_objective(entry)
				current = entry
				return


func _start_objective(entry: Dictionary) -> void:
	mission_label.text = entry["xbox"] if is_xbox else entry["pc"]
	var icon: Texture2D = entry.get("icon_xbox") if is_xbox else entry.get("icon_pc")
	mission_icon.texture = icon
	mission_icon.visible = icon != null
	match entry["kind"]:
		"use", "use_kill":
			entry["baseline"] = _count(entry["item"])
		"switch":
			entry["baseline"] = player.selected_index
	var say: String = entry.get("say", "")
	if say != "":
		_show_bubble(say)


func _is_done(entry: Dictionary) -> bool:
	match entry.get("kind", ""):
		"kill":
			return _group_dead(entry["group"])
		"pick":
			return _count(entry["item"]) > 0
		"use":
			return entry.has("baseline") and _count(entry["item"]) < entry["baseline"]
		"use_kill":
			return entry.has("baseline") and _count(entry["item"]) < entry["baseline"] and _group_dead(entry["group"])
		"switch":
			return entry.has("baseline") and player.selected_index != entry["baseline"]
		"joint":
			return joint == null or joint.amount >= JOINT_DONE_AMOUNT
		"always":
			return true
	# Réplique bloquante : terminée quand la bulle est fermée.
	return not dialogue_panel.visible


func _show_bubble(text: String) -> void:
	dialogue_label.text = text
	dialogue_panel.visible = true
	bubble_timer = BUBBLE_TIME


func _input(event: InputEvent) -> void:
	if not dialogue_panel.visible:
		return
	var pressed := false
	if event is InputEventKey:
		var key := event as InputEventKey
		pressed = key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	elif event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		pressed = pad.pressed and pad.button_index == JOY_BUTTON_A
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		pressed = click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if pressed:
		dialogue_panel.visible = false
		bubble_timer = 0.0
		get_viewport().set_input_as_handled()


# Vagues : placées à l'opposé du poulailler et jamais dans son enceinte.
func _pole_centre() -> Vector2:
	return poulailler.global_position + POULAILLER_CENTER if poulailler else player.global_position


func _away_dir() -> Vector2:
	var away: Vector2 = player.global_position - _pole_centre()
	if away.length() < 1.0:
		return Vector2.LEFT
	return away.normalized()


# offset.x : distance depuis le joueur, dans le sens opposé au poulailler ; offset.y : décalage latéral.
func _place(offset: Vector2) -> Vector2:
	var away := _away_dir()
	var pos: Vector2 = player.global_position + away * offset.x + away.orthogonal() * offset.y
	var centre := _pole_centre()
	var dir: Vector2 = pos - centre
	if dir.length() < SAFE_RADIUS:
		if dir.length() < 1.0:
			dir = away
		pos = centre + dir.normalized() * SAFE_RADIUS
	return pos


func _wave_target() -> void:
	groups["target"] = [_spawn_enemy(_place(Vector2(300, 0)), "tp")]


func _wave_second() -> void:
	groups["second"] = [_spawn_enemy(_place(Vector2(260, -160)), "grenade")]


func _wave_small() -> void:
	var centre: Vector2 = _place(Vector2(320, 0))
	groups["small"] = [
		_spawn_enemy(centre + Vector2(-50, -30), ""),
		_spawn_enemy(centre + Vector2(50, -30), ""),
		_spawn_enemy(centre + Vector2(0, 45), "nuke"),
	]


func _wave_big() -> void:
	var centre: Vector2 = _place(Vector2(480, -120))
	var big: Array = []
	for i in 8:
		big.append(_spawn_enemy(centre + Vector2.RIGHT.rotated(TAU * i / 8.0) * 90.0, ""))
	groups["big"] = big


# Rétablit la décroissance du joint et le remplit à 20 % pour le mini-jeu.
func _joint_setup() -> void:
	if joint:
		joint.duration = joint_duration
		joint.amount = 0.2


func _finish() -> void:
	_set_spawner(true)


func _spawn_enemy(pos: Vector2, drop: String) -> int:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.default_target = player
	enemy.speed = 0.0
	enemy.damage = 0.0
	enemy.forced_drop = drop
	enemies_root.add_child(enemy)
	enemy.global_position = pos
	return enemy.get_instance_id()


# Reçoit un identifiant d'instance : pas de référence vers un objet libéré.
func _dead(id: int) -> bool:
	if not is_instance_id_valid(id):
		return true
	return (instance_from_id(id) as Node).is_queued_for_deletion()


func _all_dead(ids: Array) -> bool:
	for id in ids:
		if not _dead(id):
			return false
	return true


func _group_dead(group_name: String) -> bool:
	return groups.has(group_name) and _all_dead(groups[group_name])


func _count(item: String) -> int:
	return player.items.get(item, 0)


# Met le spawner d'ennemis en pause pendant le tutoriel, puis le relance.
func _set_spawner(running: bool) -> void:
	var timer := get_tree().current_scene.get_node_or_null("Enemies/Timer") as Timer
	if timer == null:
		return
	if running:
		timer.start()
	else:
		timer.stop()
