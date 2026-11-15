extends Node2D

@export var slash_duration: float = 0.18
@export var afterimage_interval: float = 0.05
@export var fade_duration: float = 0.2

@onready var trail: Line2D = $Trail
@onready var slash: Node2D = $Slash

var source: CharacterBody2D
var direction := Vector2.RIGHT
var _elapsed: float = 0.0
var _afterimage_time: float = 0.0
var _fade_time: float = 0.0


func _ready() -> void:
	slash.rotation = direction.angle()
	var taper := Curve.new()
	taper.add_point(Vector2(0, 0))
	taper.add_point(Vector2(0.5, 1))
	taper.add_point(Vector2(1, 0))
	for index in range(slash.get_child_count()):
		var claw := slash.get_child(index) as Line2D
		claw.width_curve = taper
		var radius := 18.0 + index * 7.0
		for step in range(13):
			var angle := lerpf(-0.95, 0.95, step / 12.0)
			claw.add_point(Vector2(8, 0) + Vector2.from_angle(angle) * radius)


func _process(delta: float) -> void:
	_elapsed += delta
	var active := is_instance_valid(source) and not source.is_queued_for_deletion()
	if active:
		active = source.is_attacking and not source.dead

	if active:
		var position_now := to_local(source.global_position)
		slash.position = position_now
		if trail.get_point_count() == 0 or trail.get_point_position(
			trail.get_point_count() - 1
		).distance_to(position_now) > 1.0:
			trail.add_point(position_now)
			if trail.get_point_count() > 12:
				trail.remove_point(0)

		_afterimage_time -= delta
		if _afterimage_time <= 0.0:
			_afterimage_time = maxf(afterimage_interval, 0.01)
			spawn_afterimage()
	else:
		_fade_time += delta
		modulate.a = 1.0 - clampf(_fade_time / maxf(fade_duration, 0.01), 0.0, 1.0)
		if _fade_time >= fade_duration:
			queue_free()

	var progress := clampf(_elapsed / maxf(slash_duration, 0.01), 0.0, 1.0)
	slash.modulate.a = 1.0 - progress
	slash.scale = Vector2.ONE * lerpf(0.65, 1.15, progress)


func spawn_afterimage() -> void:
	var sprite := source.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.self_modulate = Color(1.0, 0.7, 0.35, 0.4)
	add_child(ghost)
	ghost.global_transform = sprite.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "self_modulate:a", 0.0, 0.18)
	tween.tween_callback(ghost.queue_free)
