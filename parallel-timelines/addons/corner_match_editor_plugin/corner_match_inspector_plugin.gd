extends EditorInspectorPlugin

var CornerMatchEditorProperty = preload("res://addons/corner_match_editor_plugin/corner_match_editor_property.gd")

func _can_handle(object: Object) -> bool:
	return object is CornerMatch

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if name == "matching_tiles":
		add_property_editor(name, CornerMatchEditorProperty.new())
		return true # Remove built-in editor
	return false
