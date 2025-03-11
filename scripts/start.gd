extends Node2D

func _on_texture_button_ready() -> void:
	#changing stretch mode
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT


func _on_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/level/main_level.tscn")
