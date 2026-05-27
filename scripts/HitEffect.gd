extends Node3D

@export var star_count: int = 5
@export var star_size: float = 0.08
@export var rise_height: float = 0.3
@export var lifetime: float = 1.0
@export var spread: float = 1.0  # Multiplier for horizontal spread
@export var distance: float = 1.0  # Multiplier for fall distance / height

static func spawn(world_position: Vector3, count: int = 5):
	var script = preload("res://scripts/HitEffect.gd")
	var effect = Node3D.new()
	effect.set_script(script)
	effect.star_count = count
	effect.global_position = world_position
	var world_root = Engine.get_main_loop().root
	world_root.add_child(effect)
	effect.start_effect()

static func spawn_big(world_position: Vector3, count: int = 50):
	# Spawns 2 bursts of stars with double distance and spread
	var script = preload("res://scripts/HitEffect.gd")
	
	# First burst
	var effect1 = Node3D.new()
	effect1.set_script(script)
	effect1.star_count = count
	effect1.star_size = 0.12
	effect1.spread = 2.5
	effect1.distance = 2.0
	effect1.rise_height = 0.6
	effect1.lifetime = 1.5
	effect1.global_position = world_position
	var world_root = Engine.get_main_loop().root
	world_root.add_child(effect1)
	effect1.start_effect()
	
	# Second burst (delayed slightly)
	var effect2 = Node3D.new()
	effect2.set_script(script)
	effect2.star_count = count
	effect2.star_size = 0.10
	effect2.spread = 2.5
	effect2.distance = 2.0
	effect2.rise_height = 0.6
	effect2.lifetime = 1.5
	effect2.global_position = world_position
	world_root.add_child(effect2)
	# Schedule second burst after a short delay
	effect2.set_process(false)
	await effect1.get_tree().create_timer(0.3).timeout
	if is_instance_valid(effect2):
		effect2.start_effect()

func start_effect():
	for i in range(star_count):
		var star = MeshInstance3D.new()
		star.mesh = BoxMesh.new()
		star.mesh.size = Vector3(star_size, star_size, star_size)
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.2, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1, 0.1, 0.05)
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		star.material_override = mat
		
		var offset = Vector3(
			randf_range(-0.2 * spread, 0.2 * spread),
			randf_range(-0.1, 0.3),
			randf_range(-0.2 * spread, 0.2 * spread)
		)
		star.position = offset
		
		star.rotation = Vector3(
			randf_range(0, PI * 2),
			randf_range(0, PI * 2),
			randf_range(0, PI * 2)
		)
		
		add_child(star)
		
		var tween = create_tween()
		tween.set_parallel(true)
		
		tween.tween_property(star, "position:y", offset.y + rise_height * distance, 0.1)
		
		tween.tween_property(star, "rotation", star.rotation + Vector3(
			randf_range(-4 * distance, 4 * distance),
			randf_range(-4 * distance, 4 * distance),
			randf_range(-4 * distance, 4 * distance)
		), lifetime).set_delay(0.1)
		
		tween.tween_property(star, "position:y", -5.0, lifetime * 0.9 * distance).set_delay(0.1).set_ease(Tween.EASE_IN)
		
		tween.tween_property(star, "scale", Vector3.ZERO, lifetime * 0.4).set_delay(lifetime * 0.5)
	
	await get_tree().create_timer(lifetime * distance + 0.3).timeout
	queue_free()
