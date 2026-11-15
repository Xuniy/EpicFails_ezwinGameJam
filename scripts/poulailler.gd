extends StaticBody2D

const SOUND_EFFECT = preload("res://scripts/sound_effect.gd")
const DAMAGE_SOUND = preload("res://sounds/degats_poulailler.wav")

@export var max_health: float = 500.0
@export_range(0.0, 1.0, 0.05) var occluded_opacity: float = 0.3
@export_range(0.0, 1.0, 0.05) var fade_duration: float = 0.15
@onready var health: float = max_health
@onready var building: Node2D = $Ferme/Batiment
@onready var visibility_area: Area2D = $ZoneTransparence

var _occluded: bool = false
var _fade_tween: Tween


func _physics_process(_delta: float) -> void:
	var occupied := false
	for body in visibility_area.get_overlapping_bodies():
		if body is CharacterBody2D and not body.is_queued_for_deletion():
			occupied = true
			break

	if occupied == _occluded:
		return

	_occluded = occupied
	var target_alpha := occluded_opacity if occupied else 1.0
	if _fade_tween != null:
		_fade_tween.kill()

	if fade_duration <= 0.0:
		building.modulate.a = target_alpha
	else:
		_fade_tween = create_tween()
		_fade_tween.tween_property(building, "modulate:a", target_alpha, fade_duration)


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return

	health = clampf(health - amount, 0.0, max_health)
	if amount > 0.0:
		SOUND_EFFECT.play_at(DAMAGE_SOUND, self)
	print("[Poulailler] Vie : ", health, "/", max_health)

	if health <= 0.0:
		print("[Poulailler] Détruit !")
		EndScreen.show_end(get_tree(), "Le Poulailler a été détruit par les envahisseurs")
