extends Button
class_name TooltipButton

func _make_custom_tooltip(for_text):
	if for_text.is_empty():
		return null
	var tooltip = preload("res://scenes/ui/tooltip.tscn").instantiate()
	var rich_text = tooltip.find_child("RichTextLabel")
	rich_text.text = for_text
	return tooltip
