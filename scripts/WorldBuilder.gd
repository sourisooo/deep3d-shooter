extends Node3D

@export var player_scene: PackedScene
@export var zombie_scene: PackedScene

func _ready():
	# Load and instance House
	var house_scene = load("res://scenes/House.tscn")
	var house = house_scene.instantiate()
	add_child(house)
	
	# Instance player
	var player = player_scene.instantiate()
	player.position = Vector3(0, 0.5, 7)
	add_child(player)
	
	# Instance zombies
	var z_positions = [
		Vector3(3, 0.5, 3),
		Vector3(-3, 0.5, -3),
		Vector3(5, 4, 5)
	]
	for pos in z_positions:
		var zombie = zombie_scene.instantiate()
		zombie.position = pos
		add_child(zombie)
