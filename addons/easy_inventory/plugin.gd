@tool
class_name EasyInventoryPlugin
extends EditorPlugin

const AUTOLOAD_NAME: String = "Inventory"
const AUTOLOAD_PATH: String = "res://addons/easy_inventory/inventory_manager.gd"

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	add_custom_type("ItemPickup3D", "Area3D", preload("res://addons/easy_inventory/item_pickup_3d.gd"), null)
	add_custom_type("InventoryUI", "CanvasLayer", preload("res://addons/easy_inventory/ui/inventory_ui.gd"), null)

func _exit_tree() -> void:
	remove_custom_type("ItemPickup3D")
	remove_custom_type("InventoryUI")
	remove_autoload_singleton(AUTOLOAD_NAME)
