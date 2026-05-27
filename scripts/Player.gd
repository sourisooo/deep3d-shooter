extends CharacterBody3D

@export var speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var shoot_range: float = 50.0
@export var max_health: int = 3

@onready var camera: Camera3D = $PlayerCam
@onready var health_ui: Control = $HealthUI

var health: int
var can_shoot: bool = true

func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	health = max_health
	update_health_ui()

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)

func _physics_process(delta):
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()
	
	if global_position.y < -10:
		global_position = Vector3(2, 2, 2)
		velocity = Vector3.ZERO
	
	if Input.is_action_just_pressed("shoot") and can_shoot:
		shoot()

func shoot():
	can_shoot = false
	
	var from = camera.global_position
	var dir = -camera.global_transform.basis.z
	var to = from + dir * shoot_range
	
	var hit_pos = to
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.hit_from_inside = true
	query.hit_back_faces = true
	query.collide_with_areas = true
	var result = space.intersect_ray(query)
	
	if result:
		hit_pos = result.position
		var hit = result.collider
		if hit.has_method("hit"):
			hit.hit(hit_pos)
	
	# Bullet as child of world root for stable global positioning
	var world_root = get_tree().root
	var bullet = MeshInstance3D.new()
	bullet.mesh = SphereMesh.new()
	bullet.scale = Vector3(0.3, 0.3, 0.3)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.9, 0, 1)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.9, 0, 1)
	mat.emission_energy_multiplier = 2.0
	bullet.material_override = mat
	
	world_root.add_child(bullet)
	bullet.global_position = from
	
	var light = OmniLight3D.new()
	light.light_energy = 3.0
	light.light_color = Color(1, 0.9, 0)
	bullet.add_child(light)
	
	var tween = create_tween()
	tween.tween_property(bullet, "global_position", hit_pos, 0.15)
	tween.tween_callback(bullet.queue_free)
	
	await get_tree().create_timer(0.3).timeout
	can_shoot = true

func take_damage(amount: int):
	health -= amount
	if health < 0:
		health = 0
	update_health_ui()
	
	# Spawn hit stars in front of the player
	_spawn_player_hit_effect()
	
	# Show red vignette border
	_show_damage_vignette()
	
	if health <= 0:
		die()

func _spawn_player_hit_effect():
	# Spawn stars at a position in front of the camera
	var spawn_pos = camera.global_position - camera.global_transform.basis.z * 1.5
	spawn_pos.y += 0.5
	var script = preload("res://scripts/HitEffect.gd")
	if script:
		script.spawn(spawn_pos, 5)

func _show_damage_vignette():
	var vignette_layer = get_node_or_null("DamageVignetteLayer")
	if vignette_layer:
		var vignette = vignette_layer.get_node_or_null("DamageVignette")
		if vignette:
			vignette.show()
			vignette.color = Color(0.8, 0.05, 0.05, 0.35)
			var tween = create_tween()
			tween.tween_property(vignette, "color", Color(0.8, 0.05, 0.05, 0), 1.5).set_ease(Tween.EASE_OUT)
			tween.tween_callback(vignette.hide)

func update_health_ui():
	for i in range(max_health):
		var heart = health_ui.get_child(i)
		if heart:
			heart.visible = i < health

func die():
	get_tree().reload_current_scene()

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
