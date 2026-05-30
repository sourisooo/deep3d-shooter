extends CharacterBody3D

@export var speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var shoot_range: float = 50.0
@export var max_health: int = 10

@onready var camera: Camera3D = $PlayerCam
@onready var health_ui: Control = $HealthUI
@onready var leon_animator: Node3D = $LeonFollow

var health: int
var can_shoot: bool = true
var was_moving: bool = false

# Aim dot (3D)
var aim_dot: MeshInstance3D

# First person gun
var fp_gun: Node3D

# Recoil angle for aim dot (radians)
var _fp_recoil_angle: float = 0.0

# Grab debuff (80% speed reduction)
var _grab_timer: float = 0.0
var _grab_cooldown_timer: float = 0.0
const GRAB_DURATION: float = 0.4
const GRAB_COOLDOWN: float = 4.0
const GRAB_SPEED_MULT: float = 0.2

# Kill buff variables (zombie kill)
var _has_kill_buff: bool = false
var _buff_timer: float = 0.0
const BUFF_DURATION: float = 5.0
const BUFF_RECOIL_ANGLE: float = 20.0
const BUFF_RECOIL_RETURN: float = 0.6
const BUFF_COOLDOWN: float = 0.6

# Target buff variables (target kill)
var _has_target_buff: bool = false
var _target_buff_timer: float = 0.0
const TARGET_BUFF_DURATION: float = 3.0
const TARGET_BUFF_RECOIL_ANGLE: float = 10.0
const TARGET_BUFF_RECOIL_RETURN: float = 0.3
const TARGET_BUFF_COOLDOWN: float = 0.3

# Camera perspective toggle
enum CameraView { THIRD_PERSON, FIRST_PERSON }
var current_view: int = CameraView.THIRD_PERSON
var camera_tween: Tween

# Camera positions relative to Player body
var third_person_pos := Vector3(0.5, 1.5, 3.0)
var first_person_pos := Vector3(0, 1.5, -2.5)
@onready var leon_mesh: Node3D = $LeonFollow/Model if $LeonFollow.has_node("Model") else $LeonFollow

func _ready():
	# Create aim dot
	var dot_mesh = SphereMesh.new()
	dot_mesh.radius = 0.03
	dot_mesh.height = 0.06
	var dot_mat = StandardMaterial3D.new()
	dot_mat.albedo_color = Color(1, 0, 0, 0.8)
	dot_mat.emission_enabled = true
	dot_mat.emission = Color(1, 0, 0)
	dot_mat.emission_energy_multiplier = 1.5
	aim_dot = MeshInstance3D.new()
	aim_dot.mesh = dot_mesh
	aim_dot.material_override = dot_mat
	add_child(aim_dot)
	
	# Create first person floating gun (child of camera)
	fp_gun = Node3D.new()
	
	# Gun body
	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.08, 0.06, 0.2)
	var gun_mat = StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.3, 0.3, 0.35)
	gun_mat.metallic = 0.8
	gun_mat.roughness = 0.3
	body.mesh = body_mesh
	body.material_override = gun_mat
	body.position = Vector3(0, 0, -0.1)
	fp_gun.add_child(body)
	
	# Gun barrel
	var barrel = MeshInstance3D.new()
	var barrel_mesh = CylinderMesh.new()
	barrel_mesh.top_radius = 0.015
	barrel_mesh.bottom_radius = 0.025
	barrel_mesh.height = 0.15
	var barrel_mat = StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.15, 0.15, 0.2)
	barrel_mat.metallic = 0.9
	barrel_mat.roughness = 0.2
	barrel.mesh = barrel_mesh
	barrel.material_override = barrel_mat
	barrel.position = Vector3(0, 0.04, -0.15)
	barrel.rotation.x = deg_to_rad(90)
	fp_gun.add_child(barrel)
	
	# Gun grip
	var grip = MeshInstance3D.new()
	var grip_mesh = BoxMesh.new()
	grip_mesh.size = Vector3(0.04, 0.08, 0.03)
	var grip_mat = StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.2, 0.15, 0.1)
	grip_mat.metallic = 0.4
	grip_mat.roughness = 0.7
	grip.mesh = grip_mesh
	grip.material_override = grip_mat
	grip.position = Vector3(0, -0.05, -0.05)
	fp_gun.add_child(grip)
	
	# Position gun in front of camera (bottom-right of view)
	fp_gun.position = Vector3(0.25, -0.25, -0.4)
	camera.add_child(fp_gun)
	fp_gun.visible = false  # Start hidden (3rd person)
	
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	health = max_health
	update_health_ui()

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)
	
	if event.is_action_pressed("toggle_camera"):
		toggle_camera_view()

func _physics_process(delta):
	# Update grab timers
	if _grab_timer > 0:
		_grab_timer -= delta
	if _grab_cooldown_timer > 0:
		_grab_cooldown_timer -= delta
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var is_moving = input_dir.length_squared() > 0
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Update kill buff timer (zombie)
	if _has_kill_buff:
		_buff_timer -= delta
		if _buff_timer <= 0:
			_has_kill_buff = false
	
	# Update target buff timer
	if _has_target_buff:
		_target_buff_timer -= delta
		if _target_buff_timer <= 0:
			_has_target_buff = false
	
	# Update aim dot
	_update_aim_dot()
	
	# Leon visibility in first person
	if leon_animator:
		if current_view == CameraView.FIRST_PERSON:
			leon_animator.visible = false
		else:
			leon_animator.visible = true
	
	# Leon animation
	if leon_animator:
		if is_moving:
			leon_animator.set_walking()
			was_moving = true
		else:
			if was_moving:
				leon_animator.set_idle()
				was_moving = false
	
	if _grab_timer > 0 and direction:
		# 80% speed reduction during grab
		velocity.x = direction.x * speed * GRAB_SPEED_MULT
		velocity.z = direction.z * speed * GRAB_SPEED_MULT
	elif direction:
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
	
	if leon_animator:
		leon_animator.set_shooting()
	
	# Recoil: rotate gun upward in first person
	if fp_gun and fp_gun.visible:
		var recoil_angle: float
		var return_time: float
		
		if _has_target_buff:
			recoil_angle = TARGET_BUFF_RECOIL_ANGLE
			return_time = TARGET_BUFF_RECOIL_RETURN
		elif _has_kill_buff:
			recoil_angle = BUFF_RECOIL_ANGLE
			return_time = BUFF_RECOIL_RETURN
		else:
			recoil_angle = 40.0
			return_time = 1.0
		
		var recoil_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
		recoil_tween.tween_property(fp_gun, "rotation:x", deg_to_rad(recoil_angle), 0.02)
		recoil_tween.tween_property(fp_gun, "rotation:x", 0.0, return_time)
		
		# Also apply recoil to the aim dot raycast direction
		_fp_recoil_angle = deg_to_rad(recoil_angle)
		var recoil_reset = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
		recoil_reset.tween_property(self, "_fp_recoil_angle", 0.0, return_time)
	
	# In 3rd person, shoot from Leon's position; in 1st person from camera
	var from: Vector3
	var dir: Vector3
	
	if current_view == CameraView.THIRD_PERSON and leon_animator:
		# Shoot from Leon's chest/arm level
		from = leon_animator.global_position + Vector3(0.5, 0.8, -0.5)
		dir = -camera.global_transform.basis.z
	else:
		from = camera.global_position
		dir = -camera.global_transform.basis.z
	
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
	
	var cooldown: float
	if _has_target_buff:
		cooldown = TARGET_BUFF_COOLDOWN
	elif _has_kill_buff:
		cooldown = BUFF_COOLDOWN
	else:
		cooldown = 1.0
	await get_tree().create_timer(cooldown).timeout
	can_shoot = true

func activate_kill_buff():
	_has_kill_buff = true
	_buff_timer = BUFF_DURATION

func activate_target_buff():
	_has_target_buff = true
	_target_buff_timer = TARGET_BUFF_DURATION

func heal(amount: int):
	health += amount
	if health > max_health:
		health = max_health
	update_health_ui()

func take_damage(amount: int):
	health -= amount
	if health < 0:
		health = 0
	update_health_ui()
	
	_spawn_player_hit_effect()
	_show_damage_vignette()
	
	# Apply grab debuff - 80% speed reduction for 0.4s (only if cooldown passed)
	if _grab_cooldown_timer <= 0:
		_grab_timer = GRAB_DURATION
		_grab_cooldown_timer = GRAB_COOLDOWN
	
	if health <= 0:
		die()

func _spawn_player_hit_effect():
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

func toggle_camera_view():
	if current_view == CameraView.THIRD_PERSON:
		current_view = CameraView.FIRST_PERSON
		if camera_tween:
			camera_tween.kill()
		camera_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		camera_tween.tween_property(camera, "position", first_person_pos, 0.3)
		# Show floating gun in first person
		if fp_gun:
			fp_gun.visible = true
	else:
		current_view = CameraView.THIRD_PERSON
		if camera_tween:
			camera_tween.kill()
		camera_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		camera_tween.tween_property(camera, "position", third_person_pos, 0.3)
		# Hide floating gun in third person
		if fp_gun:
			fp_gun.visible = false

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_aim_dot():
	if not aim_dot:
		return
	
	# Use the same origin as the bullet for the raycast
	# In 3rd person: shoot from Leon; in 1st person: from camera
	var from: Vector3
	var dir: Vector3
	
	if current_view == CameraView.THIRD_PERSON and leon_animator:
		from = leon_animator.global_position + Vector3(0.5, 0.8, -0.5)
		dir = -camera.global_transform.basis.z
	else:
		from = camera.global_position
		dir = -camera.global_transform.basis.z
		# Apply recoil: rotate direction up by the recoil angle
		if abs(_fp_recoil_angle) > 0.001:
			dir = dir.rotated(camera.global_transform.basis.x.normalized(), _fp_recoil_angle)
	
	var to = from + dir * shoot_range
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.hit_from_inside = true
	var result = space.intersect_ray(query)
	
	var hit_pos = to
	if result:
		hit_pos = result.position
	
	aim_dot.global_position = hit_pos
	aim_dot.visible = true


