@tool
class_name EasySavePlugin
extends EditorPlugin

const AUTOLOAD_NAME: String = "SaveSystem"
const AUTOLOAD_PATH: String = "res://addons/easy_save/save_system.gd"

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
