extends Control

@onready var player = $"../../Player"
@onready var poulailler = $"../../poulailler"

@onready var player_bar: HealthBar = $VBoxContainer/vieplayer
@onready var coop_bar: HealthBar = $VBoxContainer/viepoulailler
@onready var compass = $Compass
@onready var hotbar = $Hotbar


func _ready() -> void:
	player_bar.max_value = player.max_health
	coop_bar.max_value = poulailler.max_health

	compass.target = poulailler
	hotbar.player = player

	update_health_bars()


func _process(_delta: float) -> void:
	update_health_bars()


func update_health_bars() -> void:
	player_bar.value = player.health
	coop_bar.value = poulailler.health
