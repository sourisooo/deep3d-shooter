extends CharacterBody3D

@export var max_health: int = 2
@export var move_speed: float = 2.5
@export var attack_range: float = 2.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.5

var health: int
var player: Node3D = null
var can_attack: bool = true

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var attack_timer: Timer = $AttackTimer
@onready var health_bar: Node3D = $HealthBar3D

const HIT_EFFECT = preload("res://scripts/HitEffect.gd")
const KILL_TRACKER = preload("res://scripts/KillTracker.gd")

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
	
	velocity = dir * move_speed
	
	if dir.length() > 0:
		look_at(global_position + dir, Vector3.UP)
	
	move_and_slide()
	
	if dist <= attack_range and can_attack:
		attack()

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

func hit(hit_position := global_position):
	_spawn_hit_effect(hit_position)
	take_damage(1)

func take_damage(amount: int):
	health -= amount
	print("Zombie took damage! Health: ", health)
	
	# Update health bar
	if health_bar and health_bar.has_method("set_health_ratio"):
		health_bar.set_health_ratio(float(health) / float(max_health))
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.2, 0.2)
	mesh_instance.material_override = mat
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(mesh_instance):
		mesh_instance.material_override = null
	
	if health <= 0:
		die()

func _spawn_hit_effect(pos: Vector3):
	if HIT_EFFECT:
		HIT_EFFECT.spawn(pos, 5)

func die():
	# Check if this is a special kill (every 3rd)
	var is_special = KILL_TRACKER.register_kill()
	
	if is_special:
		_spawn_big_effect()
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	await tween.finished
	queue_free()

func _spawn_big_effect():
	if HIT_EFFECT:
		HIT_EFFECT.spawn_big(global_position, 50)

func _on_attack_timer_timeout():
	can_attack = true
