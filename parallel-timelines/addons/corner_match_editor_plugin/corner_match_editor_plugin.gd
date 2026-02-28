@tool
extends EditorPlugin

var plugin

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	plugin = preload("res://addons/corner_match_editor_plugin/corner_match_inspector_plugin.gd").new()
	add_inspector_plugin(plugin)


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	remove_inspector_plugin(plugin)
