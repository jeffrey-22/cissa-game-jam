# Script for camera
# For now just have it be a child of the player
# in the level scene tree and follow the player around
extends Camera2D
class_name Camera

# Position smoothing speed, by default 5px/s
# Might want to speed up if the body grows larger
# As well as zoom out
@export var smoothing_speed = 5.0
# Zoom scale, might want to increase as body size increase
@export var zoom_scale = 1.0

func _process(_delta: float) -> void:
	position_smoothing_speed = smoothing_speed
	zoom = Vector2(zoom_scale, zoom_scale)
