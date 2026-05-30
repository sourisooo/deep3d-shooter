extends Area3D

## Hitbox for individual body parts.
## When hit by the player's raycast, forwards hit() to the parent Target.
## Supports damage multipliers (e.g., 2.0 for headshots).

@export var damage_multiplier: float = 1.0
@export var part_name: String = ""

func hit(hit_position := global_position):
	var target = get_parent()
	while target and not target.has_method("hit"):
		target = target.get_parent()
	
	if target and target.has_method("hit"):
		# Pass the hit position for visual effects
		target.hit(hit_position)
		# Apply extra damage from multiplier (e.g., headshot 2x = 1 extra damage)
		if damage_multiplier > 1.0 and target.has_method("take_damage"):
			var extra = int(damage_multiplier) - 1
			if extra > 0:
				target.take_damage(extra)
		# Reduced damage for limbs (0.5x means no extra, but we could do half later)
		# Currently limbs do normal damage via hit() which is fine
