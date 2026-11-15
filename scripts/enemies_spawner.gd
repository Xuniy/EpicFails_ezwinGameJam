extends Node2D

signal wave_started(number: int)
signal wave_completed(number: int)
signal campaign_completed

enum State { IDLE, PREPARATION, DIALOGUE, FIGHT, COMPLETE }

const WAVE_DIALOGUE := preload("res://scences/wave_dialogue.tscn")
const VICTORY_SCREEN := preload("res://scences/victory_screen.tscn")
const FOX_SCENE := preload("res://scences/ennemy2.tscn")
const FARMER_SCENE := preload("res://scences/ennemy.tscn")
const BOSS_SCENE := preload("res://scences/ennemy3.tscn")
const BOSS_TEXTURE := preload("res://assets/boss_saut_sheet_2rows.png")
const FOX_FRAMES := preload("res://assets/fox_frames.tres")
const FARMER_FRAMES := preload("res://assets/farmer_frames.tres")
const SPEAKERS := ["Renard Malicieux", "Fred le fermier", "Lapin de Pâques"]
const DIALOGUES := [
	[
		"Héhéhé, voilà un beau petit poulailler où on pourra se régaler.\n\nAllez mes chers compatriotes, régalons-nous !",
	],
	[
		"C’est quoi ce boucan ? Qu’est-ce qui se passe dans ma ferme ?\n\nOula, mais il n’a pas l’air très bien ce poulet… HEIN, IL EST ARMÉ ???!! Et il est totalement défoncé ??!",
		"J’appelle mes jumeaux ! Abattons ce poulet et reprenons nos œufs !!",
	],
	[
		"C’est bien une odeur d’œufs frais que je sens ici ??\n\nHihihi… Mes petits poulets, j’arrive…",
	],
]

const DIALOGUE_VOICES := [
	[preload("res://sounds/dialogue_renard.wav")],
	[preload("res://sounds/dialog1_fred.wav"), preload("res://sounds/dialog2_fred.wav")],
	[preload("res://sounds/dialogue_lapin.wav")],
]
const DIALOGUE_VOLUME_DB := [-3.0, 3.0, 3.0]

@export_group("Vagues")
@export_range(0.0, 15.0, 0.5) var post_tutorial_delay: float = 3.0
@export_range(1.0, 600.0, 1.0) var wave_1_duration: float = 60.0
@export_range(1.0, 600.0, 1.0) var wave_2_duration: float = 60.0
@export_range(0.1, 10.0, 0.1) var spawn_interval: float = 2.0
@export var spawn_radius: float = 1000.0
@export var screen_margin: float = 100.0
## Scène du Lapin : default_target = poulailler, focus_player/return_to_coop pour le joueur.
@export var boss_scene: PackedScene = BOSS_SCENE
@export var boss_portrait: Texture2D

@onready var poulailler: Node2D = $"../poulailler"
@onready var player: Node2D = $"../Player"
@onready var timer: Timer = $Timer
@onready var wave_label: Label = $"../UI_en_sah/HUD/WaveStatus"

var state: State = State.IDLE
var wave_number: int = 0
var preparation_time_left: float = 0.0
var wave_time_left: float = 0.0
var wave_spawned: int = 0
var boss_defeated: bool = false
var alive_enemies: int = 0
var boss_pending: bool = false
var spawn_attempts: int = 0
var spawned_enemies: int = 0
var _dialogue: CanvasLayer
var _boss: Node2D


func _ready() -> void:
	timer.stop()
	timer.wait_time = spawn_interval
	timer.timeout.connect(spawn_enemy)
	if boss_portrait == null:
		var portrait := AtlasTexture.new()
		portrait.atlas = BOSS_TEXTURE
		portrait.region = Rect2(0, 0, 64, 64)
		boss_portrait = portrait
	_start_without_intro.call_deferred()


func _start_without_intro() -> void:
	if get_parent().has_node("Intro") or GameState.show_tutorial:
		return
	for child in get_parent().get_children():
		if child is TutorialOverlay:
			return
	start_campaign()


func start_campaign() -> void:
	if state != State.IDLE or GameState.game_over:
		return
	state = State.PREPARATION
	preparation_time_left = post_tutorial_delay
	_update_status()


func _process(delta: float) -> void:
	if GameState.game_over:
		timer.stop()
		return
	if state == State.PREPARATION:
		preparation_time_left = maxf(0.0, preparation_time_left - delta)
		_update_status()
		if preparation_time_left <= 0.0:
			_show_wave_dialogue(1)
	elif state == State.FIGHT and wave_number < 3:
		wave_time_left = maxf(0.0, wave_time_left - delta)
		_update_status()
		if wave_time_left <= 0.0:
			_check_wave_complete()


func _show_wave_dialogue(number: int) -> void:
	if GameState.game_over:
		return
	wave_number = number
	state = State.DIALOGUE
	timer.stop()
	wave_label.text = "Vague %d / 3" % wave_number
	_dialogue = WAVE_DIALOGUE.instantiate()
	_dialogue.speaker_name = SPEAKERS[number - 1]
	_dialogue.pages = PackedStringArray(DIALOGUES[number - 1])
	_dialogue.voice_pages.assign(DIALOGUE_VOICES[number - 1])
	_dialogue.voice_volume_db = DIALOGUE_VOLUME_DB[number - 1]
	match number:
		1:
			_dialogue.portrait = FOX_FRAMES.get_frame_texture(&"walk_down", 0)
		2:
			_dialogue.portrait = FARMER_FRAMES.get_frame_texture(&"walk_down", 0)
		3:
			_dialogue.portrait = boss_portrait
	_dialogue.finished.connect(_begin_wave)
	get_parent().add_child(_dialogue)


func _begin_wave() -> void:
	if state != State.DIALOGUE or GameState.game_over:
		return
	state = State.FIGHT
	wave_time_left = wave_1_duration if wave_number == 1 else wave_2_duration
	wave_spawned = 0
	boss_pending = wave_number == 3
	boss_defeated = false
	if wave_number == 3:
		# Les survivants des vagues précédentes poursuivent aussi le joueur.
		for enemy in get_children():
			if enemy.is_in_group("enemies"):
				enemy.default_target = player
				enemy.focus_player(player)
				if "player_only" in enemy:
					enemy.player_only = true
	# Relâcher le bouton de dialogue ne doit pas tirer/lancer un objet.
	player._left_consumed = true
	player._left_was_down = false
	player._throw_trigger_held = false
	wave_started.emit(wave_number)
	_update_status()
	timer.start(spawn_interval)
	spawn_enemy()


func spawn_enemy() -> void:
	if state != State.FIGHT or GameState.game_over:
		return
	if wave_number < 3 and wave_time_left <= 0.0:
		_check_wave_complete()
		return
	spawn_attempts += 1
	var is_boss := boss_pending
	var location := _find_spawn_position(is_boss)
	if location == Vector2.INF:
		return
	var scene: PackedScene = boss_scene if is_boss else _small_enemy_scene()
	if scene == null:
		return
	var enemy: Node2D = scene.instantiate()
	if "default_target" in enemy:
		enemy.default_target = player if wave_number == 3 and not is_boss else poulailler
	if "player_only" in enemy:
		enemy.player_only = wave_number == 3 and not is_boss
	enemy.position = to_local(location)
	alive_enemies += 1
	enemy.tree_exited.connect(_on_enemy_removed)
	if is_boss:
		_boss = enemy
		boss_pending = false
		enemy.defeated.connect(_on_boss_defeated)
		enemy.tree_exited.connect(_on_boss_removed)
	else:
		wave_spawned += 1
	add_child(enemy)
	enemy.add_to_group("enemies")
	spawned_enemies += 1
	_update_status()


func _small_enemy_scene() -> PackedScene:
	match wave_number:
		1:
			return FOX_SCENE
		2:
			return FARMER_SCENE
	# Alterner garantit la présence des deux espèces dans la troisième vague.
	return FOX_SCENE if wave_spawned % 2 == 0 else FARMER_SCENE


func _find_spawn_position(is_boss: bool = false) -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		camera.force_update_scroll()
	var screen := get_viewport().get_visible_rect().grow(screen_margin)
	var shape := CircleShape2D.new()
	shape.radius = 140.0 if is_boss else 50.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 3
	var space := get_world_2d().direct_space_state
	# Élargir la couronne si la caméra montre déjà tous les points à 1 000 px.
	for radius in [spawn_radius, spawn_radius * 1.5, spawn_radius * 2.0, spawn_radius * 3.0]:
		var start_angle := randf() * TAU
		for index in range(24):
			var location: Vector2 = poulailler.global_position + Vector2.RIGHT.rotated(start_angle + index * TAU / 24.0) * radius
			if screen.has_point(get_viewport().get_canvas_transform() * location):
				continue
			query.transform = Transform2D(0.0, location)
			if space.intersect_shape(query, 1).is_empty():
				return location
	return Vector2.INF


func _on_enemy_removed() -> void:
	if not is_inside_tree() or not get_parent().is_inside_tree():
		return
	alive_enemies = maxi(0, alive_enemies - 1)
	_update_status()
	# Le dialogue suivant est créé hors du traitement des collisions.
	_check_wave_complete.call_deferred()


func _on_boss_defeated() -> void:
	if state != State.FIGHT or wave_number != 3:
		return
	boss_defeated = true
	_check_wave_complete.call_deferred()


func _on_boss_removed() -> void:
	# Une suppression extérieure n’est pas une victoire : le boss réapparaîtra.
	if state == State.FIGHT and wave_number == 3 and not boss_defeated and not GameState.game_over:
		boss_pending = true


func _check_wave_complete() -> void:
	if state != State.FIGHT or GameState.game_over:
		return
	if wave_number < 3 and wave_time_left > 0.0:
		return
	if wave_number == 3 and not boss_defeated:
		return
	timer.stop()
	wave_completed.emit(wave_number)
	if wave_number < 3:
		_show_wave_dialogue(wave_number + 1)
	else:
		state = State.COMPLETE
		# Après la victoire, les petits ennemis restants ne poursuivent plus la partie.
		for enemy in get_children():
			if enemy.is_in_group("enemies"):
				enemy.queue_free()
		_update_status()
		campaign_completed.emit()
		get_parent().add_child(VICTORY_SCREEN.instantiate())


func _update_status() -> void:
	if state == State.PREPARATION:
		wave_label.text = "Les ennemis approchent… %d" % ceili(preparation_time_left)
	elif state == State.COMPLETE:
		wave_label.text = "Poulailler protégé !"
	elif state == State.FIGHT and wave_number < 3:
		var seconds := ceili(wave_time_left)
		wave_label.text = "Vague %d / 3 — %d:%02d" % [wave_number, seconds / 60, seconds % 60]
	elif state == State.FIGHT:
		wave_label.text = "Vague 3 / 3 — Vaincs le Lapin de Pâques !"
