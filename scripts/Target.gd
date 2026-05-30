extends CharacterBody3D

signal killed(grid_pos: Vector2i)

var hp: int = 3
var max_hp: int = 3
var speed: float = 1.5
var time: float = 0.0
var player_ref: Node = null
var damage_cooldown: float = 0.0
var aggro_range: float = 30.0
var is_aggroed: bool = false
var target_grid_pos: Vector2i = Vector2i(-1, -1)

const HIT_EFFECT = preload("res://scripts/HitEffect.gd")
const KILL_TRACKER = preload("res://scripts/KillTracker.gd")

@onready var left_arm: MeshInstance3D = $HitArea/LeftArmHitbox/Mesh
@onready var right_arm: MeshInstance3D = $HitArea/RightArmHitbox/Mesh
@onready var left_leg: MeshInstance3D = $HitArea/LeftLegHitbox/Mesh
@onready var right_leg: MeshInstance3D = $HitArea/RightLegHitbox/Mesh
@onready var head_mesh: MeshInstance3D = $HitArea/HeadHitbox/Mesh
@onready var body_mesh: MeshInstance3D = $HitArea/BodyHitbox/Mesh
@onready var health_bar: Node3D = $HealthBar3D

func _ready():
	hp = max_hp
	var area = $HitArea
	if area:
		area.body_entered.connect(_on_hit_area_body_entered)
	
	if health_bar and health_bar.has_method("set_health_ratio"):
		health_bar.set_health_ratio(float(hp) / float(max_hp))

func _physics_process(delta):
	time += delta * speed
	damage_cooldown = max(damage_cooldown - delta, 0)
	
	if not player_ref or (not is_instance_valid(player_ref)):
		player_ref = get_tree().get_first_node_in_group("player")
	
	if is_aggroed:
		if not player_ref:
			# No player found, can't chase
			velocity = Vector3(0, velocity.y, 0)
			move_and_slide()
			return
		var dir = (player_ref.global_position - global_position)
		var dist = dir.length()
		dir.y = 0
		if dir.length() > 0.01:
			var look_dir = dir.normalized()
			look_at(global_position + look_dir, Vector3.UP)
			if dist < aggro_range and dist > 1.5:
				velocity = Vector3(look_dir.x * speed, velocity.y, look_dir.z * speed)
			elif dist <= 1.5:
				velocity = Vector3(0, velocity.y, 0)
				if dist < 1.8 and damage_cooldown == 0:
					damage_cooldown = 1.5
					if player_ref.has_method("take_damage"):
						player_ref.take_damage(1)
			else:
				velocity = Vector3(0, velocity.y, 0)
	else:
		# Not aggroed - attack if player is close, otherwise stay still
		if player_ref:
			var dir = (player_ref.global_position - global_position)
			var dist = dir.length()
			dir.y = 0
			if dist < 1.8 and damage_cooldown == 0:
				damage_cooldown = 1.5
				if player_ref.has_method("take_damage"):
					player_ref.take_damage(1)
		velocity = Vector3(0, velocity.y, 0)
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()
	
	left_arm.position = Vector3(-0.5, 1.0, 0.3)
	right_arm.position = Vector3(0.5, 1.0, 0.3)
	left_arm.rotation = Vector3(0, 0, -1.57)
	right_arm.rotation = Vector3(0, 0, 1.57)
	
	left_leg.rotation.x = sin(time * 4.0) * 0.5
	right_leg.rotation.x = sin(time * 4.0 + PI) * 0.5


func hit(hit_position := global_position):
	print("Target hit() called!")
	# Spawn hit effect at the hit location
	_spawn_hit_effect(hit_position)
	is_aggroed = true
	_activate_aggro()
	
	hp -= 1
	
	if health_bar and health_bar.has_method("set_health_ratio"):
		health_bar.set_health_ratio(float(hp) / float(max_hp))
	
	# Flash white on hit
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	if head_mesh:
		head_mesh.material_override = mat
	if body_mesh:
		body_mesh.material_override = mat
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(self):
		if head_mesh:
			head_mesh.material_override = null
		if body_mesh:
			body_mesh.material_override = null
	
	if hp <= 0:
		_die()

func take_damage(amount: int):
	hp -= amount
	is_aggroed = true
	_activate_aggro()
	if health_bar and health_bar.has_method("set_health_ratio"):
		health_bar.set_health_ratio(float(hp) / float(max_hp))
	if hp <= 0:
		_die()

func _activate_aggro():
	if is_aggroed:
		return
	is_aggroed = true
	print("Target aggro activated!")
	
	# Visual feedback - flash orange to indicate aggro
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.4, 0)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.2, 0)
	mat.emission_energy_multiplier = 0.8
	if head_mesh:
		head_mesh.material_override = mat
	if body_mesh:
		body_mesh.material_override = mat
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self):
		if head_mesh:
			head_mesh.material_override = null
		if body_mesh:
				body_mesh.material_override = null

func _die():
	var is_special = KILL_TRACKER.register_kill()
	if is_special and HIT_EFFECT:
		HIT_EFFECT.spawn_big(global_position, 50)
	
	# Activate target buff on player (faster recoil/fire rate for 5s)
	if player_ref and player_ref.has_method("activate_target_buff"):
		player_ref.activate_target_buff()
	
	killed.emit(target_grid_pos)
	set_physics_process(false)
	call_deferred("queue_free")

func _spawn_hit_effect(pos: Vector3):
	if HIT_EFFECT:
		HIT_EFFECT.spawn(pos, 5)

func _on_hit_area_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(1)
