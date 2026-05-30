extends Node3D

## Floating 3D health bar that sits above an entity.
## Call set_health_ratio(0.0 to 1.0) to update.

@export var bar_width: float = 0.8
@export var bar_height: float = 0.1
@export var bar_offset_y: float = 2.0  # Height above origin
@export var bg_color: Color = Color(0.2, 0.2, 0.2, 0.8)
@export var fg_color: Color = Color(0.0, 1.0, 0.0, 1.0)
@export var damage_color: Color = Color(1.0, 0.2, 0.2, 1.0)

var bg_mesh: MeshInstance3D
var fg_mesh: MeshInstance3D
var bg_mat: StandardMaterial3D
var fg_mat: StandardMaterial3D

func _ready():
	# Background bar (dark)
	bg_mesh = MeshInstance3D.new()
	bg_mesh.mesh = BoxMesh.new()
	bg_mesh.mesh.size = Vector3(bar_width, bar_height, 0.02)
	bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_color = bg_color
	bg_mat.flags_transparent = true
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mesh.material_override = bg_mat
	bg_mesh.position = Vector3(0, bar_offset_y, 0)
	add_child(bg_mesh)
	
	# Foreground bar (colored)
	fg_mesh = MeshInstance3D.new()
	fg_mesh.mesh = BoxMesh.new()
	fg_mesh.mesh.size = Vector3(bar_width, bar_height, 0.03)
	fg_mat = StandardMaterial3D.new()
	fg_mat.albedo_color = fg_color
	fg_mat.flags_transparent = true
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mesh.material_override = fg_mat
	fg_mesh.position = Vector3(0, bar_offset_y, 0.01)
	add_child(fg_mesh)
	
	# Always face camera (billboard)
	bg_mesh.set_as_toplevel(true)
	fg_mesh.set_as_toplevel(true)

func _process(_delta):
	# Billboard: always face the camera
	if bg_mesh and fg_mesh and get_viewport():
		var cam = get_viewport().get_camera_3d()
		if cam:
			var pos = global_position + Vector3(0, bar_offset_y, 0)
			bg_mesh.global_position = pos
			fg_mesh.global_position = pos
			var look_target = cam.global_position
			var dir = (look_target - pos).normalized()
			bg_mesh.look_at(pos + dir, Vector3.UP)
			fg_mesh.look_at(pos + dir, Vector3.UP)

func set_health_ratio(ratio: float):
	ratio = clamp(ratio, 0.0, 1.0)
	if fg_mesh and is_instance_valid(fg_mesh):
		fg_mesh.scale.x = max(ratio, 0.001)
		# Shift so bar shrinks from the right
		var half_width = bar_width * 0.5
		fg_mesh.position.x = -half_width * (1.0 - ratio)
		
		# Color change based on health
		if ratio > 0.5:
			fg_mat.albedo_color = fg_color
		elif ratio > 0.25:
			fg_mat.albedo_color = Color(1.0, 0.8, 0.0, 1.0)  # Yellow
		else:
			fg_mat.albedo_color = damage_color  # Red

func hide_bar():
	visible = false

func show_bar():
	visible = true
