extends CharacterBody3D

## Animated zombie using premade 3D meshes with run/attack animations.
## Uses Target-style health, hitboxes, and damage system.

## Movement & combat
@export var move_speed: float = 2.5
@export var attack_range: float = 2.5
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.5

## Health
@export var hp: int = 3
@export var max_hp: int = 3

signal killed(grid_pos: Vector2i)

var player: Node3D = null
var can_attack: bool = true
var is_aggroed: bool = false
var target_grid_pos: Vector2i = Vector2i(-1, -1)

# Animation
var model_root: Node3D = null
var animation_player: AnimationPlayer = null
var current_anim: String = ""

# Hitbox meshes for damage flash
var head_mesh: MeshInstance3D
var body_mesh: MeshInstance3D
var health_bar: Node3D

const HIT_EFFECT = preload("res://scripts/HitEffect.gd")
const KILL_TRACKER = preload("res://scripts/KillTracker.gd")

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	
	# --- Health setup (from Target) ---
	hp = max_hp
	
	head_mesh = $HitArea/HeadHitbox/HeadMesh
	body_mesh = $HitArea/BodyHitbox/BodyMesh
	health_bar = $HealthBar3D
	
	var area = $HitArea
	if area:
		area.body_entered.connect(_on_hit_area_body_entered)
	
	if health_bar and health_bar.has_method("set_health_ratio"):
		health_bar.set_health_ratio(float(hp) / float(max_hp))
	
	# --- Animation setup ---
	var run_scene = preload("res://assets/godot_imports/zombie_run.glb")
	var attack_scene = preload("res://assets/godot_imports/zombie_attack.glb")
	
	model_root = run_scene.instantiate()
	add_child(model_root)
	model_root.position.y = -0.85  # Feet on ground
	model_root.scale = Vector3(1.5, 1.5, 1.5)
	model_root.rotation.y = deg_to_rad(180)
	
	animation_player = _find_animation_player(model_root)
	
	# Copy attack animation into main player
	var attack_model = attack_scene.instantiate()
	add_child(attack_model)
	attack_model.visible = false
	
	var attack_ap = _find_animation_player(attack_model)
	
	if animation_player and attack_ap:
		var library = animation_player.get_animation_library("")
		if not library:
			library = AnimationLibrary.new()
			animation_player.add_animation_library("", library)
		
		for anim_name in attack_ap.get_animation_list():
			var anim = attack_ap.get_animation(anim_name)
			if anim:
				var attack_key = "attack"
				if library.has_animation(attack_key):
					library.remove_animation(attack_key)
				library.add_animation(attack_key, anim)
		
		attack_model.queue_free()
	
	# Start playing
	if animation_player:
		var anim_list = animation_player.get_animation_list()
		if "run" in anim_list:
			animation_player.play("run")
			current_anim = "run"
		elif anim_list.size() > 0:
			var found = false
			for a in anim_list:
				if "run" in a.to_lower():
					animation_player.play(a)
					current_anim = a
					found = true
					break
			if not found:
				animation_player.play(anim_list[0])
				current_anim = anim_list[0]
		animation_player.seek(0.0, true)

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found = _find_animation_player(child)
		if found:
			return found
	return null

func _physics_process(delta):
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
	
	var dir_3d = (player.global_position - global_position)
	var flat_dir = Vector3(dir_3d.x, 0, dir_3d.z)
	var dist = flat_dir.length()
	
	if dist > 0.1:
		flat_dir = flat_dir.normalized()
	
	if not is_aggroed:
		velocity = Vector3.ZERO
		_play_anim("idle")
		if flat_dir.length() > 0:
			look_at(global_position + flat_dir, Vector3.UP)
		# Attack if player is close even when not aggroed
		if dist <= attack_range and can_attack:
			_attack_player()
		return
	
	if dist <= attack_range:
		velocity = Vector3.ZERO
		_play_anim("attack")
		if can_attack:
			_attack_player()
	elif dist < 30.0:
		velocity = flat_dir * move_speed
		_play_anim("run")
	else:
		velocity = Vector3.ZERO
		_play_anim("idle")
	
	if flat_dir.length() > 0:
		look_at(global_position + flat_dir, Vector3.UP)
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()

func _play_anim(anim_name: String):
	if not animation_player:
		return
	if anim_name == "idle":
		if animation_player.is_playing():
			animation_player.pause()
		return
	if current_anim == anim_name and animation_player.is_playing():
		return
	var anim_list = animation_player.get_animation_list()
	if anim_name in anim_list:
		animation_player.play(anim_name)
		current_anim = anim_name
	elif anim_list.size() > 0:
		animation_player.play(anim_list[0])
		current_anim = anim_list[0]

func _attack_player():
	can_attack = false
	if is_instance_valid(player):
		var d = global_position.distance_to(player.global_position)
		if d <= attack_range + 0.5:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

# === Target-style hit & damage ===

func hit(hit_position := global_position):
	print("DisplayModel hit() called!")
	_spawn_hit_effect(hit_position)
	is_aggroed = true
	_activate_aggro()
	hp -= 1
	
	if health_bar and health_bar.has_method("set_health_ratio"):
		health_bar.set_health_ratio(float(hp) / float(max_hp))
	
	# Flash white on hit
	if model_root:
		var children = model_root.find_children("*", "MeshInstance3D", true)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(5, 5, 5)
		mat.emission_enabled = true
		mat.emission = Color(1, 1, 1)
		for m in children:
			if m is MeshInstance3D:
				m.material_override = mat
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(self) and model_root:
			for m in children:
				if is_instance_valid(m):
					m.material_override = null
	
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
	print("DisplayModel aggro activated!")
	
	# Visual feedback - flash orange to indicate aggro
	if model_root:
		var children = model_root.find_children("*", "MeshInstance3D", true)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.4, 0)
		mat.emission_enabled = true
		mat.emission = Color(1, 0.2, 0)
		mat.emission_energy_multiplier = 0.8
		for m in children:
			if m is MeshInstance3D:
				m.material_override = mat
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(self) and model_root:
			for m in children:
				if is_instance_valid(m):
					m.material_override = null

func _die():
	var is_special = KILL_TRACKER.register_kill()
	if is_special and HIT_EFFECT:
		HIT_EFFECT.spawn_big(global_position, 50)
	
	killed.emit(target_grid_pos)
	set_physics_process(false)
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	await tween.finished
	queue_free()

func _spawn_hit_effect(pos: Vector3):
	if HIT_EFFECT:
		HIT_EFFECT.spawn(pos, 5)

func _on_hit_area_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(1)
