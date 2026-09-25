extends SceneTree
func _init():
	var scene = load("res://Scenes/meja_bisa_dibuka.tscn").instantiate()
	root.add_child(scene)
	
	print("--- INITIAL STATE ---")
	print("is_open: ", scene.is_open)
	print("Drawer position Z: ", scene.drawer_node.position.z)
	print("ItemSlot visible: ", scene.item_slot.visible)
	print("Prompt: ", scene.get_interaction_prompt())
	
	print("--- OPENING DRAWER ---")
	scene.interact()
	print("is_open: ", scene.is_open)
	print("Drawer target position Z: ", scene.drawer_node.position.z)
	print("ItemSlot visible: ", scene.item_slot.visible)
	print("Prompt: ", scene.get_interaction_prompt())
	
	print("--- CLOSING DRAWER ---")
	scene.interact()
	print("is_open: ", scene.is_open)
	print("Drawer target position Z: ", scene.drawer_node.position.z)
	print("ItemSlot visible: ", scene.item_slot.visible)
	print("Prompt: ", scene.get_interaction_prompt())
	
	quit()
