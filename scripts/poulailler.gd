extends StaticBody2D

@export var max_health: float = 500.0
@onready var health: float = max_health


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return

	health = clampf(health - amount, 0.0, max_health)
	print("[Poulailler] Vie : ", health, "/", max_health)

	if health <= 0.0:
		print("[Poulailler] Détruit !")
		EndScreen.show_end(get_tree(), "Le Poulailler a été détruit par les envahisseurs")
