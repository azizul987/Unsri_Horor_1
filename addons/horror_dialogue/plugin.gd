@tool
class_name HorrorDialoguePlugin
extends EditorPlugin

const AUTOLOAD_NAME: String = "HorrorDialogue"
const AUTOLOAD_PATH: String = "res://addons/horror_dialogue/core/horror_dialogue_manager.gd"

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	add_custom_type("DialogueTrigger3D", "Area3D", preload("res://addons/horror_dialogue/3d/dialogue_trigger_3d.gd"), null)
	add_custom_type("DialogueInteractable3D", "Area3D", preload("res://addons/horror_dialogue/3d/dialogue_interactable_3d.gd"), null)

func _exit_tree() -> void:
	remove_custom_type("DialogueTrigger3D")
	remove_custom_type("DialogueInteractable3D")
	remove_autoload_singleton(AUTOLOAD_NAME)
