class_name TutorialOverlay
extends CanvasLayer

## Tutoriel scénarisé en jeu, guidé par Maître Coq. Chaque étape attend que le joueur
## fasse l'action (tuer, ramasser, utiliser un objet). La mission reste en haut au centre ensuite.

const ENEMY_SCENE := preload("res://scences/ennemy.tscn")
const ICON_MOUSE := preload("res://assets/tutoriel/mouse.png")
const ICON_RT := preload("res://assets/tutoriel/xbox_rt.png")
const ICON_LT := preload("res://assets/tutoriel/xbox_lt.png")
const SPEAKER := "Maître Coq"
const ICON_SIZE: float = 42.0

# Référence untyped volontairement : les méthodes du joueur et du HUD sont appelées dynamiquement.
var player
var joint
var enemies_root: Node
var is_xbox: bool = false
var _advance: bool = false
var _waiting_advance: bool = false

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
	enemies_root = scene.get_node_or_null("Enemies")
	if enemies_root == null:
		enemies_root = scene
	is_xbox = GameState.input_device == GameState.DEVICE_XBOX

	_build_ui()
	_run()


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


# Scénario : cible -> pearl -> second ennemi -> grenade sur petit groupe -> bomba sur gros groupe -> joint -> mission.
func _run() -> void:
	_set_spawner(false)

	await _say("Chicken Norris ! Des renards et des fermiers attaquent notre poulailler.")
	await _say("Ton but : le protéger. Si ta vie ou celle du poulailler tombe à zéro, c'est perdu.")
	await _say("Commence par t'entraîner. Une cible apparaît devant toi.")

	var target := _spawn_enemy(player.global_position + Vector2(300, 0), "tp")
	await _objective("Tire sur l'ennemi devant toi (clic gauche).", "Tire sur l'ennemi devant toi (RT).",
		ICON_MOUSE, ICON_RT, func(): return _dead(target))

	await _say("Bien visé ! Il a laissé une eggder pearl.")
	await _objective("Ramasse l'eggder pearl.", "Ramasse l'eggder pearl.", null, null,
		func(): return _count("tp") > 0)
	await _say("L'eggder pearl te téléporte au point visé, si la place est libre.")
	var pearl_count := _count("tp")
	await _objective("Lance l'eggder pearl : clic droit maintenu, puis clic gauche.",
		"Lance l'eggder pearl : LT maintenu, puis RT.", ICON_MOUSE, ICON_LT,
		func(): return _count("tp") < pearl_count)

	await _say("Un second ennemi approche, il a laissé une grenade.")
	var second := _spawn_enemy(player.global_position + Vector2(-260, -160), "grenade")
	await _objective("Tue le second ennemi (clic gauche).", "Tue le second ennemi (RT).",
		ICON_MOUSE, ICON_RT, func(): return _dead(second))

	await _say("La grenade explose à sa chute et blesse les ennemis proches.")
	await _objective("Ramasse la grenade.", "Ramasse la grenade.", null, null,
		func(): return _count("grenade") > 0)

	await _say("Un petit groupe approche. Lance la grenade au milieu.")
	var centre: Vector2 = player.global_position + Vector2(320, 0)
	var small: Array = [
		_spawn_enemy(centre + Vector2(-50, -30), ""),
		_spawn_enemy(centre + Vector2(50, -30), ""),
		_spawn_enemy(centre + Vector2(0, 45), "nuke"),
	]
	var grenade_count := _count("grenade")
	await _objective("Lance la grenade sur le petit groupe : clic droit, puis clic gauche.",
		"Lance la grenade sur le petit groupe : LT, puis RT.", ICON_MOUSE, ICON_LT,
		func(): return _count("grenade") < grenade_count and _all_dead(small))

	await _say("Un des ennemis a laissé une egg bomba. Elle élimine tous les ennemis de son rayon.")
	await _objective("Ramasse l'egg bomba.", "Ramasse l'egg bomba.", null, null,
		func(): return _count("nuke") > 0)

	await _say("Un gros groupe arrive. Lance l'egg bomba au centre des ennemis.")
	var big_centre: Vector2 = player.global_position + Vector2(480, -120)
	var big: Array = []
	for i in 8:
		big.append(_spawn_enemy(big_centre + Vector2.RIGHT.rotated(TAU * i / 8.0) * 90.0, ""))
	var nuke_count := _count("nuke")
	await _objective("Lance l'egg bomba sur le gros groupe : clic droit, puis clic gauche.",
		"Lance l'egg bomba sur le gros groupe : LT, puis RT.", ICON_MOUSE, ICON_LT,
		func(): return _count("nuke") < nuke_count and _all_dead(big))

	await _say("Ton joint est presque vide. Quand il est vide, tu perds de la vie.")
	if joint:
		joint.amount = 0.2
	await _say("Chaque bonne touche au bon moment ajoute cinq secondes au joint.")
	await _objective("Fume : touche A, puis 1, 2, 3 ou 4 au bon moment.",
		"Fume : croix haut, puis Y, X, A ou B au bon moment.", null, null,
		func(): return joint == null or joint.amount >= 1.0)

	await _say("Parfait. Tu es prêt. Protège le poulailler !")
	_set_spawner(true)
	await _objective("Protège le poulailler.", "Protège le poulailler.", null, null,
		func(): return true)


# Attend un appui sur Entrée, A ou clic gauche, puis masque la bulle.
func _say(text: String) -> void:
	speaker_label.text = SPEAKER
	dialogue_label.text = text
	dialogue_panel.visible = true
	_advance = false
	_waiting_advance = true
	while not _advance:
		await get_tree().process_frame
	_waiting_advance = false
	dialogue_panel.visible = false


# Affiche l'objectif (texte et icône selon l'appareil), puis attend que la condition soit remplie.
func _objective(text_pc: String, text_xbox: String, icon_pc: Texture2D, icon_xbox: Texture2D, done: Callable) -> void:
	mission_label.text = text_xbox if is_xbox else text_pc
	var icon: Texture2D = icon_xbox if is_xbox else icon_pc
	mission_icon.texture = icon
	mission_icon.visible = icon != null
	while not done.call():
		await get_tree().process_frame


func _input(event: InputEvent) -> void:
	if not _waiting_advance:
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
		_advance = true
		get_viewport().set_input_as_handled()


func _spawn_enemy(pos: Vector2, drop: String) -> Node2D:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.default_target = player
	enemy.speed = 0.0
	enemy.damage = 0.0
	enemy.forced_drop = drop
	enemies_root.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _dead(enemy: Node) -> bool:
	return not is_instance_valid(enemy) or enemy.is_queued_for_deletion()


func _all_dead(enemies: Array) -> bool:
	for enemy in enemies:
		if not _dead(enemy):
			return false
	return true


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
