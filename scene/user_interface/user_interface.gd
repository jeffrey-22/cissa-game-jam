# UserInterface Node.
# Manages different UI elements in the UI scene.
#
# To use:
# 
# 
extends CanvasLayer
class_name UserInterface

@onready var color_rect: ColorRect = $ColorRect
@onready var label: RichTextLabel = $RichTextLabel

func _ready() -> void:
	Globals.user_interface_node = self
	color_rect.modulate.a = 0
	label.modulate.a = 0
	
var is_ending_sequence_called = false	

func start_ending_sequence() -> void:
	if is_ending_sequence_called:
		return
	is_ending_sequence_called = true
	color_rect.visible = true
	label.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, 6.0)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 6.0)
	await tween.finished
	label.text = "\nThanks for playing!\nAsset Credits:\nGlacial Mountains assets by Vnitti"
	label.text += "\nPixel Fantasy Caves assets by Szadi art"
	label.text += "\nWinter Pixel Art Asset Pack by haladrias"
	label.text += "\nIndustrial Tileset assets by Atomic Realm"
	label.text += "\nPixelated UI sfx by Atelier Magicae"
	
