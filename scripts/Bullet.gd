extends Node3D

var direction: Vector3
var speed: float = 50.0
var lifetime: float = 2.0

func _ready():
	# Create a small glowing sphere for the bullet
	var mesh = MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.scale = Vector3(0.1, 0.1, 0.1)
	add_child(mesh)
	
	var light = OmniLight3D.new()
	light.light_energy = 0.5
	add_child(light)
	
	# Start movement
	var tween = create_tween()
	tween.tween_property(self, "position", position + direction * speed * lifetime, lifetime)
	tween.tween_callback(queue_free)
