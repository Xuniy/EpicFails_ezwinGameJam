extends StaticBody2D

signal defeated

var health: float = 15.0


func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0 or is_queued_for_deletion():
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		defeated.emit()
		queue_free()


func focus_player(_player: Node2D) -> void:
	pass


func return_to_coop() -> void:
	pass
