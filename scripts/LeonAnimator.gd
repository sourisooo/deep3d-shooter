extends Node3D

@onready var model: Node3D = $Model
@onready var walk_anim: Node3D = $WalkAnim
@onready var shoot_anim: Node3D = $ShootAnim
@onready var gun_anchor: Node3D = $GunAnchor

var current_anim: Node3D
var is_shooting: bool = false

# Store the base transform to lock animation nodes in place
var base_position := Vector3.ZERO
var base_rotation := Vector3.ZERO
var base_scale := Vector3.ONE

func _physics_process(_delta):
	# Lock before physics animations play (prevents root motion from ever applying)
	_lock_current_anim()

func _process(_delta):
	# Lock after rendering to catch any remaining drift
	_lock_current_anim()
	
	# Safety: enforce only the current_anim is visible
	for n in [model, walk_anim, shoot_anim]:
		if n and is_instance_valid(n):
			n.visible = (n == current_anim)

func _lock_current_anim():
	if current_anim and current_anim != model:
		current_anim.position = base_position
		current_anim.rotation = base_rotation
		current_anim.scale = base_scale
		
		# Also lock the skeleton root bone which is where GLB root motion lives
		for child in current_anim.get_children(true):
			if child is Skeleton3D:
				child.position = Vector3.ZERO
				child.rotation = Vector3.ZERO

func _ready():
	# Start with model visible, others hidden
	walk_anim.visible = false
	shoot_anim.visible = false
	model.visible = true
	current_anim = model

func _find_skeleton(node: Node) -> Skeleton3D:
	for child in node.get_children(true):
		if child is Skeleton3D:
			return child
		var found = _find_skeleton(child)
		if found:
			return found
	return null

func _find_ap(node: Node) -> AnimationPlayer:
	for child in node.get_children(true):
		if child is AnimationPlayer:
			return child
		var found = _find_ap(child)
		if found:
			return found
	return null

func set_idle():
	if is_shooting:
		return
	_set_active(model)

func set_walking():
	if is_shooting:
		return
	_set_active(walk_anim)

func set_running():
	if is_shooting:
		return
	_set_active(walk_anim)

func set_shooting():
	if is_shooting:
		return
	is_shooting = true
	_set_active(shoot_anim)
	await get_tree().create_timer(0.5).timeout
	is_shooting = false
	set_idle()

func _set_active(anim_node: Node3D):
	if current_anim == anim_node:
		return
	
	# Stop any current animation
	var old_ap = _find_ap(current_anim) if current_anim else null
	if old_ap and old_ap.is_playing():
		old_ap.stop()
	
	# Hide current, show new
	if current_anim:
		current_anim.visible = false
	anim_node.visible = true
	current_anim = anim_node
	
	# Copy position/rotation/scale from model reference and save as base
	base_position = model.position
	base_rotation = model.rotation
	base_scale = model.scale
	anim_node.position = base_position
	anim_node.rotation = base_rotation
	anim_node.scale = base_scale
	
	# Reset any skeleton root inside the animation node
	for child in anim_node.get_children(true):
		if child is Skeleton3D:
			child.position = Vector3.ZERO
			child.rotation = Vector3.ZERO
	
	# Play animation - strip root motion translation/rotation tracks first
	var ap = _find_ap(anim_node)
	if ap:
		var anims = ap.get_animation_list()
		if anims.size() > 0:
			# Look for the animation resource and remove root motion tracks
			var anim = ap.get_animation(anims[0])
			if anim:
				_strip_root_motion(anim, ap)
				# Make the animation loop
				anim.loop_mode = Animation.LOOP_LINEAR
			ap.play(anims[0])

func _strip_root_motion(anim: Animation, ap: AnimationPlayer):
	# Remove translation/rotation tracks from root bones to prevent drifting
	var tracks_to_remove := []
	for i in anim.get_track_count():
		var track_path = anim.track_get_path(i)
		var track_name = str(track_path)
		# Root bone tracks usually look like "Skeleton3D:position" or ":root_bone:translation"
		# Check for translation and rotation tracks on the skeleton root
		if track_name.contains(":position") or track_name.contains(":translation") or \
		   track_name.contains(":rotation") or track_name.contains(":quaternion") or \
		   track_name.contains(":scale"):
			# Only remove if it's on the root bone (parent skeleton node)
			# These are the root motion tracks that cause forward movement
			tracks_to_remove.append(i)
	
	# Remove from highest index to lowest to avoid index shifting
	tracks_to_remove.reverse()
	for idx in tracks_to_remove:
		anim.remove_track(idx)
