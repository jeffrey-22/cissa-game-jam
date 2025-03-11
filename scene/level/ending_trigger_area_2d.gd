extends Area2D
class_name EndingTriggerArea2D

# Ending triggered
func _on_body_entered(body: Node2D) -> void:
	Globals.user_interface_node.start_ending_sequence()
