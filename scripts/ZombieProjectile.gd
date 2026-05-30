extends Node3D

## A zombie projectile that travels toward the player.
## It can be destroyed by shooting it (has a hit() method).
## Slow enough to be dodged or shot out of the air.

var target_player: Node3D = null
var direction: Vector3 = Vector3.ZERO
var speed: float = 6.0
var lifetime: float = 5.0
var damage: int = 1
var age: float = 0.0

var can_be_hit: bool = true

const HIT_EFFECT = preload("res://scripts/HitEffect.gd")

func _ready():
	# Visual: a greenish glowing blob
	var mesh = MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.scale = Vector3(0.5, 0.5, 0.5)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 0.2)
	mat.emission_energy_multiplier = 2.0
	mat.metallic = 0.3
	mat.roughness = 0.6
	mesh.material_override = mat
	add_child(mesh)
	
	# Glow light
	var light = OmniLight3D.new()
	light.light_energy = 1.5
	light.light_color = Color(0.2, 0.9, 0.2)
	light.omni_range = 6.0
	add_child(light)
	
	# Area for detecting when it hits the player (collides with player on layer 2)
	var hit_player_area = Area3D.new()
	hit_player_area.collision_layer = 0
	hit_player_area.collision_mask = 2  # Hit player layer

	var player_collision = CollisionShape3D.new()
	player_collision.shape = SphereShape3D.new()
	player_collision.shape.radius = 0.8
	hit_player_area.add_child(player_collision)
	add_child(hit_player_area)
	
	hit_player_area.body_entered.connect(_on_body_entered)
	hit_player_area.area_entered.connect(_on_area_entered)
	
	# Area for being hit by the player's raycast (collision layer 1 = player's raycast mask)
	var hitbox_area = Area3D.new()
	hitbox_area.collision_layer = 1  # matches player raycast mask
	hitbox_area.collision_mask = 0   # doesn't need to detect anything

	var hitbox_collision = CollisionShape3D.new()
	hitbox_collision.shape = SphereShape3D.new()
	hitbox_collision.shape.radius = 0.7
	hitbox_area.add_child(hitbox_collision)
	add_child(hitbox_area)

	# Add to a group so player can detect projectiles
	add_to_group("enemy_projectiles")

func _physics_process(delta):
	age += delta
	if age >= lifetime:
		_despawn()
		return
	
	# Move toward player if we have a direction
	if direction != Vector3.ZERO:
		position += direction * speed * delta
		
		# Rotate to face movement direction
		look_at(global_position + direction, Vector3.UP)
	
		# Direct distance check as backup collision
		if can_be_hit and target_player and is_instance_valid(target_player):
			var dist = global_position.distance_to(target_player.global_position)
			if dist < 1.6:
				_hit_player(target_player)

	# Check if we've gone too far from the world
	if global_position.y < -10:
		queue_free()

## Called when the player shoots this projectile (via raycast)
func hit(_hit_position := global_position):
	if not can_be_hit:
		return
	can_be_hit = false
	
	if HIT_EFFECT:
		HIT_EFFECT.spawn(global_position, 8)
	
	# Small pop/disappear effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(2.0, 2.0, 2.0), 0.05)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15).set_delay(0.05)
	tween.tween_callback(queue_free)

func _on_body_entered(body: Node):
	if body.has_method("take_damage") and body.is_in_group("player"):
		_hit_player(body)

func _on_area_entered(area: Area3D):
	# Check if the area's parent is the player
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage") and parent.is_in_group("player"):
		_hit_player(parent)

func _hit_player(player_node: Node):
	if not can_be_hit:
		return
	can_be_hit = false
	
	if player_node.has_method("take_damage"):
		player_node.take_damage(damage)
	
	# Splat effect
	if HIT_EFFECT:
		HIT_EFFECT.spawn(global_position, 12)
	
	queue_free()

func _despawn():
	# Fizzle out
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)

