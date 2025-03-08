# HintSquare
# Just for body entering signalling
extends Area2D
class_name HintSquare

var local_body_position: Vector2i

# Connected to body_entered
# disallow spawning obstructed, so just destroys itself
func _on_body_entered(_body: Node2D) -> void:
	queue_free()
