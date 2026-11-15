extends Node2D

var enemy_scene: PackedScene = preload("res://scences/ennemy2.tscn")
@onready var poulailler: Node2D = $"../poulailler"
@export var spawn_radius: float = 3000.0
@export var screen_margin: float = 100.0

var spawn_attempts: int = 0
var spawned_enemies: int = 0


func _ready() -> void:
	$Timer.timeout.connect(spawn_enemy)
	if $Timer.is_stopped():
		push_warning("[Spawn] Timer arrêté : active Autostart pour lancer les spawns.")
	if enemy_scene == null:
		push_warning("[Spawn] Enemy Scene n'est pas renseigné dans l'inspecteur.")
	if not is_instance_valid(poulailler):
		push_warning("[Spawn] Poulailler n'est pas renseigné dans l'inspecteur.")


func spawn_enemy() -> void:
	spawn_attempts += 1
	print("[Spawn] Tentative #", spawn_attempts)
	if enemy_scene == null or not is_instance_valid(poulailler):
		push_warning("[Spawn] Annulé : renseigne Enemy Scene et Poulailler.")
		return

	var position_spawn := poulailler.global_position \
		+ Vector2.RIGHT.rotated(randf() * TAU) * 1000.0

	var position_ecran := get_viewport().get_canvas_transform() * position_spawn

	if get_viewport().get_visible_rect().has_point(position_ecran):
		print("[Spawn] Annulé : position visible à l'écran. Monde=",
			position_spawn, ", écran=", position_ecran)
		return

	var enemy = enemy_scene.instantiate()
	enemy.default_target = poulailler
	add_child(enemy)
	enemy.global_position = position_spawn
	spawned_enemies += 1
	print("[Spawn] Ennemi #", spawned_enemies, " créé : ", enemy.get_path(),
		", position=", position_spawn, ", cible=", poulailler.name)
	return
