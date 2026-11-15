extends RefCounted


static func play_at(stream: AudioStream, source: Node2D) -> AudioStreamPlayer2D:
	# Le son reste dans le monde pour finir même si l'explosion disparaît.
	var sound := AudioStreamPlayer2D.new()
	sound.stream = stream
	source.get_tree().current_scene.add_child(sound)
	sound.global_position = source.global_position
	sound.finished.connect(sound.queue_free)
	sound.play()
	return sound
