extends Area2D

@export var speed: float = 1500.0

var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 2.0
var damage: float = 5.0


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if is_queued_for_deletion():
		return

	if body.is_in_group("enemies"):
		body.take_damage(damage)
		queue_free()
