@tool
class_name EasyPausePlugin
extends EditorPlugin

const CUSTOM_TYPE_NAME: String = "EasyPauseMenu"
const CUSTOM_TYPE_BASE: String = "CanvasLayer"
const CUSTOM_TYPE_SCRIPT: Script = preload("res://addons/easy_pause/pause_menu.gd")

func _enter_tree() -> void:
	add_custom_type(CUSTOM_TYPE_NAME, CUSTOM_TYPE_BASE, CUSTOM_TYPE_SCRIPT, null)

func _exit_tree() -> void:
	remove_custom_type(CUSTOM_TYPE_NAME)
