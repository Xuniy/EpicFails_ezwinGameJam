extends Control

@export_range(0.0, 1.0, 0.05) var damage_overlay_opacity: float = 0.7
@export_range(0.0, 2.0, 0.05) var damage_overlay_fade_time: float = 0.5

@onready var player = $"../../Player"
@onready var poulailler = $"../../poulailler"

@onready var player_bar: HealthBar = $VBoxContainer/vieplayer
@onready var coop_bar: HealthBar = $VBoxContainer/viepoulailler
@onready var compass = $Compass
@onready var hotbar = $Hotbar
@onready var blood_overlay: TextureRect = $Sang

var _previous_player_health: float
var _damage_tween: Tween


func _ready() -> void:
	player_bar.max_value = player.max_health
	coop_bar.max_value = poulailler.max_health

	compass.target = poulailler
	hotbar.player = player
	_previous_player_health = player.health
	blood_overlay.modulate.a = 0.0

	update_health_bars()


func _process(_delta: float) -> void:
	if player.health < _previous_player_health:
		show_damage_overlay()
	_previous_player_health = player.health
	update_health_bars()


func show_damage_overlay() -> void:
	if _damage_tween != null:
		_damage_tween.kill()
	blood_overlay.modulate.a = damage_overlay_opacity
	_damage_tween = create_tween()
	_damage_tween.tween_property(
		blood_overlay, "modulate:a", 0.0, damage_overlay_fade_time
	)


func update_health_bars() -> void:
	player_bar.value = player.health
	coop_bar.value = poulailler.health
