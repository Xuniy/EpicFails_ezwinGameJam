class_name TutorialOverlay
extends CanvasLayer

## Trois actions explicites, validées par des signaux. Aucun délai ne saute une étape.
enum Step { SHOOT, TELEPORT, SMOKE, FINISH }
enum Phase { EXPLANATION, WAIT_RELEASE, ACTION, COMPLETE, DONE }

const DIALOGUE_SCENE := preload("res://scences/dialogue_box.tscn")
const TARGET_SCENE := preload("res://scences/tutorial_target.tscn")
const ITEM_SCENE := preload("res://scences/item_au_sol.tscn")
const REQUIRED_HITS: int = 3
@export_range(-40.0, 12.0, 1.0) var voice_volume_db: float = 3.0
const POULAILLER_CENTER := Vector2(-80.0, 140.0)
const SAFE_RADIUS: float = 560.0
const INSTRUCTION_VOICES := [
	preload("res://sounds/dialogue1_linus.wav"),
	preload("res://sounds/dialog2_linus.wav"),
	preload("res://sounds/dialogue3_linus.wav"),
	preload("res://sounds/dialog4_linus.wav"),
]

# Les textes restent regroupés ici ; la présentation reste dans dialogue_box.tscn.
const INSTRUCTIONS := [
	"1/3 — Protège le poulailler ! Entraîne-toi sur une cible.\nPC : vise à la souris et tire avec le clic gauche.\nManette : vise au stick droit et tire avec RT.\nDéplacement : ZQSD / WASD sur PC, stick gauche à la manette.",
	"2/3 — Ramasse l’Eggde Pearl au sol devant toi, puis sélectionne-la pour te téléporter.\nPC : molette pour choisir, maintiens clic droit, vise à la souris puis clic gauche.\nManette : LB/RB pour choisir, maintiens LT, vise au stick droit puis RT.\nRelâche les clics / gâchettes pour réessayer.",
	"3/3 — Réussis 3 notes pour apprendre à fumer.\nPC : A ouvre le mini-jeu ; utilise 1, 2, 3, 4 au bon moment.\nManette : croix haut ouvre le mini-jeu ; utilise Y, X, A, B.\nLes ratés ne remettent pas tes réussites à zéro.",
	"Tu es prêt ! Protège ta vie et celle du poulailler.\nGrenade : 60 dégâts autour de l’impact. Nuke : 400 dégâts dans sa zone.\nPC : molette, clic droit pour viser puis clic gauche.\nManette : LB/RB, LT pour viser puis RT.\nGarde ton joint rempli pour ne pas perdre de vie."
]

var step: Step = Step.SHOOT
var phase: Phase = Phase.EXPLANATION
var successful_hits: int = 0
var player
var joint
var rhythm
var enemies_root: Node
var spawn_timer: Timer
var training_target: Node2D
var training_pearl: Area2D
var dialogue_panel: Control
var dialogue_label: Label
var dialogue_hint: Label
var dialogue_voice: AudioStreamPlayer
var markers: OffscreenMarkers

var _saved_items: Dictionary
var _saved_selection: int
var _saved_consumption_paused: bool
var _saved_enemy_process_mode: Node.ProcessMode
var _spawner_was_running: bool
var _cleaned_up: bool = false
var _confirm_held: bool = true
var _held_confirmation_inputs: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var world := get_tree().current_scene
	player = world.get_node_or_null("Player")
	joint = world.get_node_or_null("UI_en_sah/HUD/JointBar")
	var hud := world.get_node_or_null("UI_en_sah/HUD")
	enemies_root = world.get_node_or_null("Enemies")
	spawn_timer = world.get_node_or_null("Enemies/Timer") as Timer
	if hud != null:
		for child in hud.get_children():
			if child is RhythmGame:
				rhythm = child
	if player == null or joint == null or rhythm == null or enemies_root == null:
		push_error("Tutoriel : Player, JointBar, RhythmGame ou Enemies manquant.")
		_cleaned_up = true
		queue_free()
		return

	_saved_items = player.items.duplicate()
	_saved_selection = player.selected_index
	_saved_consumption_paused = joint.consumption_paused
	_saved_enemy_process_mode = enemies_root.process_mode
	_spawner_was_running = spawn_timer != null and not spawn_timer.is_stopped()
	if spawn_timer != null:
		spawn_timer.stop()
	enemies_root.process_mode = Node.PROCESS_MODE_DISABLED
	joint.consumption_paused = true
	joint.amount = 1.0
	rhythm._close()
	for item in player.items:
		player.items[item] = 0

	player.teleport_finished.connect(_on_teleport_finished)
	rhythm.hit_succeeded.connect(_on_rhythm_hit)
	dialogue_voice = AudioStreamPlayer.new()
	dialogue_voice.name = "DialogueVoice"
	dialogue_voice.volume_db = voice_volume_db
	add_child(dialogue_voice)
	markers = OffscreenMarkers.new()
	markers.process_mode = Node.PROCESS_MODE_PAUSABLE
	markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(markers)
	dialogue_panel = DIALOGUE_SCENE.instantiate()
	add_child(dialogue_panel)
	dialogue_label = dialogue_panel.get_node("Box/Text")
	dialogue_hint = dialogue_panel.get_node("Box/Hint")
	dialogue_panel.get_node("Box/ObjectiveIcon").hide()
	_enter_explanation(Step.SHOOT)


func _enter_explanation(next_step: Step) -> void:
	step = next_step
	phase = Phase.EXPLANATION
	_confirm_held = true
	get_tree().paused = true
	rhythm._close()
	dialogue_label.text = INSTRUCTIONS[step]
	dialogue_hint.text = "PC : Entrée / clic gauche · Manette : A"
	dialogue_hint.show()
	dialogue_panel.show()
	dialogue_voice.stop()
	dialogue_voice.stream = INSTRUCTION_VOICES[step]
	dialogue_voice.play()


func _input(event: InputEvent) -> void:
	var confirmation_id := ""
	if event is InputEventKey and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		confirmation_id = "key_%d" % event.keycode
	elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		confirmation_id = "pad_%d" % event.device
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		confirmation_id = "mouse"
	if confirmation_id != "":
		if event.is_pressed():
			_held_confirmation_inputs[confirmation_id] = true
		else:
			_held_confirmation_inputs.erase(confirmation_id)
	if phase != Phase.EXPLANATION:
		return
	if not _controls_released():
		# Le verrou est aussi remis à zéro dans _process après relâchement.
		if _confirm_held:
			get_viewport().set_input_as_handled()
			return
	if _confirm_held:
		return
	var confirm := false
	if event is InputEventKey:
		confirm = event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	elif event is InputEventJoypadButton:
		confirm = event.pressed and event.button_index == JOY_BUTTON_A
	elif event is InputEventMouseButton:
		confirm = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if confirm:
		dialogue_voice.stop()
		phase = Phase.WAIT_RELEASE
		_confirm_held = true
		dialogue_hint.text = "Relâche les boutons pour commencer."
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	match phase:
		Phase.EXPLANATION:
			if _controls_released():
				_confirm_held = false
		Phase.WAIT_RELEASE:
			if _controls_released():
				if step == Step.FINISH:
					_finish()
				else:
					_activate_action()
		Phase.COMPLETE:
			_enter_explanation((int(step) + 1) as Step)
		Phase.ACTION:
			if step == Step.TELEPORT:
				dialogue_hint.text = "Objectif : réussis une téléportation." if player.items["tp"] > 0 else "Objectif : avance sur l’Egg Pearl pour la ramasser."


func _controls_released() -> bool:
	if not _held_confirmation_inputs.is_empty():
		return false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return false
	for action in ["tir", "use_item", "ui_accept", "ui_gauche", "ui_droite"]:
		if Input.get_action_raw_strength(action) > 0.05:
			return false
	for key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_A, KEY_1, KEY_2, KEY_3, KEY_4]:
		if Input.is_key_pressed(key):
			return false
	for device in Input.get_connected_joypads():
		for button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_DPAD_UP]:
			if Input.is_joy_button_pressed(device, button):
				return false
	return true


func _activate_action() -> void:
	# La phase est active avant de créer les objets ou d'autoriser les commandes.
	phase = Phase.ACTION
	player.aiming_item = false
	player.mouse_throw_item = ""
	player._throw_trigger_held = false
	player._right_was_down = false
	player._left_was_down = false
	player._left_consumed = false
	player._throw_zoom_active = false
	dialogue_label.text = INSTRUCTIONS[step]
	match step:
		Step.SHOOT:
			_spawn_target()
			dialogue_hint.text = "Objectif : élimine la cible."
		Step.TELEPORT:
			player.selected_index = player.item_order.find("grenade")
			_spawn_pearl()
			dialogue_hint.text = "Objectif : avance sur l’Egg Pearl pour la ramasser."
		Step.SMOKE:
			joint.amount = 0.2
			successful_hits = 0
			dialogue_hint.text = "Réussites : 0 / 3"
	get_tree().paused = false


func _spawn_pearl() -> void:
	if is_instance_valid(training_pearl):
		training_pearl.queue_free()
	var direction: Vector2 = player.facing_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2.DOWN
	var spawn_position: Vector2 = player.global_position + direction * 120.0
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 3
	query.exclude = [player.get_rid()]
	var found := false
	for distance in [120.0, 180.0, 80.0]:
		for angle in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, PI]:
			var candidate: Vector2 = player.global_position + direction.rotated(angle) * distance
			query.transform = Transform2D(0.0, candidate)
			if player.get_world_2d().direct_space_state.intersect_shape(query).is_empty():
				spawn_position = candidate
				found = true
				break
		if found:
			break
	training_pearl = ITEM_SCENE.instantiate()
	training_pearl.item_type = "tp"
	get_tree().current_scene.add_child(training_pearl)
	training_pearl.global_position = spawn_position


func _spawn_target() -> void:
	if phase != Phase.ACTION or step != Step.SHOOT:
		return
	training_target = TARGET_SCENE.instantiate()
	training_target.defeated.connect(_on_target_defeated)
	training_target.tree_exited.connect(_on_target_removed)
	enemies_root.add_child(training_target)
	training_target.global_position = _target_position()


func _target_position() -> Vector2:
	var coop := get_tree().current_scene.get_node_or_null("poulailler") as Node2D
	var center: Vector2 = coop.global_position + POULAILLER_CENTER if coop != null else player.global_position
	var away: Vector2 = center.direction_to(player.global_position)
	if away.is_zero_approx():
		away = Vector2.LEFT
	var shape := CircleShape2D.new()
	shape.radius = 35.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 3
	query.exclude = [player.get_rid(), training_target.get_rid()]
	for distance in [260.0, 360.0, 180.0]:
		for angle in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, PI]:
			var candidate: Vector2 = player.global_position + away.rotated(angle) * distance
			if candidate.distance_to(center) < SAFE_RADIUS:
				candidate = center + center.direction_to(candidate) * SAFE_RADIUS
			query.transform = Transform2D(0.0, candidate)
			if player.get_world_2d().direct_space_state.intersect_shape(query).is_empty():
				return candidate
	return player.global_position + away * 360.0


func _on_target_defeated() -> void:
	if phase == Phase.ACTION and step == Step.SHOOT:
		_complete_action()


func _on_target_removed() -> void:
	# Une suppression extérieure ne valide pas la cible : on la recrée.
	if phase == Phase.ACTION and step == Step.SHOOT:
		_spawn_target.call_deferred()


func _on_teleport_finished(succeeded: bool, origin: Vector2, destination: Vector2) -> void:
	if phase != Phase.ACTION or step != Step.TELEPORT:
		return
	if succeeded and origin.distance_to(destination) >= 24.0:
		_complete_action()
	else:
		if player.items["tp"] == 0:
			_spawn_pearl()
		player.cycle_item(0)
		dialogue_hint.text = "Ramasse la perle et vise plus loin, dans un endroit libre."


func _on_rhythm_hit() -> void:
	if phase != Phase.ACTION or step != Step.SMOKE:
		return
	successful_hits += 1
	dialogue_hint.text = "Réussites : %d / %d" % [successful_hits, REQUIRED_HITS]
	if successful_hits >= REQUIRED_HITS:
		_complete_action()


func _complete_action() -> void:
	if phase != Phase.ACTION:
		return
	phase = Phase.COMPLETE
	get_tree().paused = true


func _finish() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	_restore_runtime()
	joint.amount = 1.0
	if is_instance_valid(enemies_root) and enemies_root.has_method("start_campaign"):
		enemies_root.start_campaign()
	queue_free()


func _restore_runtime() -> void:
	if _cleaned_up:
		return
	_cleaned_up = true
	if is_instance_valid(dialogue_voice):
		dialogue_voice.stop()
	phase = Phase.DONE
	if is_instance_valid(player):
		player.items = _saved_items.duplicate()
		player.selected_index = _saved_selection
		player.aiming_item = false
		player.mouse_throw_item = ""
		player._throw_zoom_active = false
	if is_instance_valid(joint):
		joint.consumption_paused = _saved_consumption_paused
	if is_instance_valid(rhythm):
		rhythm._close()
	if is_instance_valid(training_target) and not training_target.is_queued_for_deletion():
		training_target.queue_free()
	if is_instance_valid(training_pearl) and not training_pearl.is_queued_for_deletion():
		training_pearl.queue_free()
	if is_instance_valid(enemies_root):
		enemies_root.process_mode = _saved_enemy_process_mode
	if is_instance_valid(spawn_timer) and _spawner_was_running:
		spawn_timer.start()
	if is_inside_tree():
		get_tree().paused = false


func _exit_tree() -> void:
	_restore_runtime()
