extends FusionSpawner

const Playerscene=preload("res://Scenes/player_muull.tscn")

@onready var fusion_spawner: FusionSpawner = $"."
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fusion_spawner.add_spawnable_scene(Playerscene)
	Fusion.room_joined.connect(_on_room_join)
	Fusion.connect_to_photon("User"+str(randi()))
	Fusion.connected_to_photon.connect(func():
		Fusion.join_or_create_room("lobi_PUblic")
		,CONNECT_ONE_SHOT)
	
	

func _on_room_join():
	var player = fusion_spawner.spawn(Playerscene)
	if player is Node3D:
		player.global_position = Vector3(randf_range(-3.0, 3.0), -5.0, randf_range(-3.0, 3.0))
