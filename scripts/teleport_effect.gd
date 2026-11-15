extends Node2D

@export var duration: float = 0.4


func setup(origin: Vector2, destination: Vector2, sprite: AnimatedSprite2D) -> void:
	var points := PackedVector2Array([to_local(origin), to_local(destination)])
	$Glow.points = points
	$Trail.points = points
	# Des copies figées du joueur matérialisent le trajet.
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	for index in range(5):
		var progress := index / 5.0
		var ghost := Sprite2D.new()
		ghost.texture = texture
		ghost.centered = sprite.centered
		ghost.offset = sprite.offset
		ghost.flip_h = sprite.flip_h
		ghost.flip_v = sprite.flip_v
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.self_modulate = Color(0.45, 0.9, 1.0, lerpf(0.2, 0.6, progress))
		add_child(ghost)
		ghost.global_transform = sprite.global_transform
		ghost.global_position += origin.lerp(destination, progress) - destination

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)
