extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Fusion.room_joined.connect(_on_room_joined)


func _on_room_joined()->void:
	pass
