extends Node2D


func _process(_delta: float) -> void:
	var rotation := Input.get_vector(
		"sr_gauche", "sr_droite", "sr_haut", "sr_bas"
	)
	global_rotation = rotation.angle()

	
