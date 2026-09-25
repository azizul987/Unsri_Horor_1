extends MainLoop
var time = 0.0
var scene = null

func _initialize():
	pass

func _iteration(delta):
	time += delta
	if scene == null:
		scene = load("res://Scenes/meja_bisa_dibuka.tscn").instantiate()
		Engine.get_main_loop().root.add_child(scene)
		return false
	
	if time < 0.2:
		return false
		
	print("--- INITIAL STATE ---")
	print("is_open: ", scene.is_open)
	print("Drawer position Z: ", scene.drawer_node.position.z)
	print("ItemSlot visible: ", scene.item_slot.visible)
	print("Prompt: ", scene.get_interaction_prompt())
	
	print("--- OPENING DRAWER ---")
	scene.toggle_drawer()
	print("is_open: ", scene.is_open)
	print("Prompt: ", scene.get_interaction_prompt())
	
	return true
