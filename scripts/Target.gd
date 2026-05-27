extends CharacterBody3D

signal killed(grid_pos: Vector2i)

var hp: int = 3
var max_hp: int = 3
var speed: float = 1.5
var time: float = 0.0
var player_ref: Node = null
var damage_cooldown: float = 0.0
var aggro_range: float = 15.0
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
	
	if not player_ref:
		for child in get_tree().root.get_children():
			var world = child
			for c in world.get_children():
				if c is CharacterBody3D and c.name == "Player":
					player_ref = c
					break
	
	if player_ref:
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
	# Spawn hit effect at the hit location
	_spawn_hit_effect(hit_position)
	
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
	if health_bar and health_bar.has_method("set_health_ratio"):
		health_bar.set_health_ratio(float(hp) / float(max_hp))
	if hp <= 0:
		_die()

func _die():
	var is_special = KILL_TRACKER.register_kill()
	if is_special and HIT_EFFECT:
		HIT_EFFECT.spawn_big(global_position, 50)
	
	killed.emit(target_grid_pos)
	set_physics_process(false)
	call_deferred("queue_free")

func _spawn_hit_effect(pos: Vector3):
	if HIT_EFFECT:
		HIT_EFFECT.spawn(pos, 5)

func _on_hit_area_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(1)
