extends CharacterBody3D

@export var max_health: int = 2
@export var move_speed: float = 2.5
@export var attack_range: float = 2.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.5
@export var ranged_attack_range: float = 24.0
@export var projectile_speed: float = 6.0
@export var ranged_attack_cooldown: float = 3.0

var health: int
var player: Node3D = null
var can_attack: bool = true
var can_ranged_attack: bool = true
var is_aggroed: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var attack_timer: Timer = $AttackTimer
@onready var health_bar: Node3D = $HealthBar3D

const HIT_EFFECT = preload("res://scripts/HitEffect.gd")
const KILL_TRACKER = preload("res://scripts/KillTracker.gd")
const ZOMBIE_PROJECTILE = preload("res://scripts/ZombieProjectile.gd")

func _ready():
	health = max_health
	attack_timer.wait_time = attack_cooldown
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	
	if health_bar and health_bar.has_method("set_health_ratio"):
		health_bar.set_health_ratio(float(health) / float(max_health))

func _physics_process(delta):
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if not player or health <= 0:
		return
	
	var dir = (player.global_position - global_position)
	var dist = dir.length()
	dir.y = 0
	dir = dir.normalized()
	
	# Auto-aggro when player is within ranged attack range
	if dist <= ranged_attack_range:
		is_aggroed = true
	
	if not is_aggroed:
		return
	
	# Face the player
	if dir.length() > 0:
		look_at(global_position + dir, Vector3.UP)
	
	# Ranged attack at medium range (between melee and max range)
	if dist > attack_range and dist <= ranged_attack_range and can_ranged_attack:
		velocity = Vector3.ZERO
		ranged_attack()
	elif dist <= attack_range and can_attack:
		velocity = Vector3.ZERO
		attack()
	else:
		# Move toward player
		velocity = dir * move_speed
		if dist < 0.8:
			velocity = Vector3.ZERO
	
	move_and_slide()

func attack():
	can_attack = false
	attack_timer.start()
	
	var tween = create_tween()
	var lunge_dir = (player.global_position - global_position).normalized() * 0.5
	tween.tween_property(self, "global_position", global_position + lunge_dir, 0.1)
	tween.tween_callback(func():
		if is_instance_valid(player) and global_position.distance_to(player.global_position) <= attack_range + 0.5:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)
	)

func ranged_attack():
	can_ranged_attack = false
	
	# Create the projectile
	var projectile = Node3D.new()
	projectile.set_script(ZOMBIE_PROJECTILE)
	projectile.target_player = player
	projectile.speed = projectile_speed
	projectile.damage = attack_damage
	
	# Spawn from zombie's position (chest level)
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + global_transform.basis.z * -0.5
	projectile.global_position = spawn_pos
	
	# Aim directly at the player's center
	if is_instance_valid(player):
		var aim_dir = (player.global_position - spawn_pos).normalized()
		projectile.direction = aim_dir
	
	# Add to the scene tree
	var world_root = get_tree().root
	world_root.add_child(projectile)
	
	# Cooldown timer
	await get_tree().create_timer(ranged_attack_cooldown).timeout
	if is_instance_valid(self):
		can_ranged_attack = true

func hit(hit_position := global_position):
	print("Zombie hit() called!")
	_spawn_hit_effect(hit_position)
	is_aggroed = true
	_activate_aggro()
	take_damage(1)

func take_damage(amount: int):
	health -= amount
	is_aggroed = true
	_activate_aggro()
	print("Zombie took damage! Health: ", health)
	
	# Update health bar
	if health_bar and health_bar.has_method("set_health_ratio"):
		health_bar.set_health_ratio(float(health) / float(max_health))
	
	# Flash white on hit
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.2, 0.2)
	mesh_instance.material_override = mat
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(mesh_instance):
		mesh_instance.material_override = null
	
	if health <= 0:
		die()

func _activate_aggro():
	if not is_aggroed:
		is_aggroed = true
		# Optional: visual flash to indicate aggro
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.5, 0)
		mat.emission_enabled = true
		mat.emission = Color(1, 0.3, 0)
		mat.emission_energy_multiplier = 0.5
		mesh_instance.material_override = mat
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(mesh_instance):
			mesh_instance.material_override = null

func _spawn_hit_effect(pos: Vector3):
	if HIT_EFFECT:
		HIT_EFFECT.spawn(pos, 5)

func die():
	KILL_TRACKER.register_kill()
	
	# Activate buff on the player (faster recoil/fire rate for 10s)
	if player and player.has_method("activate_kill_buff"):
		player.activate_kill_buff()
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	await tween.finished
	queue_free()

func _spawn_big_effect():
	if HIT_EFFECT:
		HIT_EFFECT.spawn_big(global_position, 50)

func _on_attack_timer_timeout():
	can_attack = true


