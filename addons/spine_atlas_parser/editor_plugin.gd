@tool
extends EditorPlugin

## Mounts the Spine Atlas Parser dock in the editor's bottom panel. The runtime
## node (PackedAnimatedSprite2D) self-registers via class_name, so no custom
## type is added here.

const DOCK_SCENE := preload("res://addons/spine_atlas_parser/dock/dock.tscn")

var _dock: Control = null


func _enter_tree() -> void:
	_dock = DOCK_SCENE.instantiate()
	add_control_to_bottom_panel(_dock, "Spine Atlas Parser")


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null
