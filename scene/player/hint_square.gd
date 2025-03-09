# HintSquare
# Just for body entering signalling
# is_hiding and is_obstructed are for detecting which to snap on to
# deleted and updated every time main body structure changes
# Mainly controlled in player script
# Can be freely removed and readded
extends Area2D
class_name HintSquare

var local_body_position: Vector2i

@onready var sprite_node = $Sprite2D

# Is requested to be hiding
var is_hiding: bool = false:
	set(new_value):
		is_hiding = new_value
		update_visible_status()

# If current location is obstructed
var is_obstructed: bool = false:
	get():
		return self.has_overlapping_bodies()

func update_visible_status():
	get_tree().get_frame()
	# change sprite's visibility
	if is_hiding or is_obstructed:
		sprite_node.visible = false
	else:
		sprite_node.visible = true

func _on_body_entered(_body: Node2D) -> void:
	update_visible_status()

func _on_body_exited(_body: Node2D) -> void:
	update_visible_status()
