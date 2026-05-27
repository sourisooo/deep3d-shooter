extends Node3D

var grid: Array = []
var grid_size: Vector2i = Vector2i(50, 50)
var cell_size: float = 1.0
var zombie_registry: Dictionary = {}
var target_registry: Dictionary = {}

@export var target_scene: PackedScene
@export var zombie_scene: PackedScene
@export var max_zombies: int = 5
@export var target_count: int = 6

const KILL_TRACKER = preload("res://scripts/KillTracker.gd")

func _ready():
	_initialize_grid()
	_spawn_targets()
	_spawn_initial_zombies()

func _process(_delta):
	# Clean up dead zombies from tracking registry
	for zombie in zombie_registry.keys():
		if not is_instance_valid(zombie) or not zombie.is_inside_tree():
			var old_grid_pos = zombie_registry[zombie]
			grid[old_grid_pos.x][old_grid_pos.y] = "E"
			zombie_registry.erase(zombie)
	
	# Clean up dead targets from tracking registry
	for target in target_registry.keys():
		if not is_instance_valid(target) or not target.is_inside_tree():
			var old_grid_pos = target_registry[target]
			grid[old_grid_pos.x][old_grid_pos.y] = "E"
			target_registry.erase(target)
	
	# Fill up zombies
	if zombie_registry.size() < max_zombies:
		var new_positions = _find_empty_positions(1, 12.0, 23.0, "Z")
		if new_positions.size() > 0:
			_spawn_zombie_at(new_positions[0])
	
	# Fill up targets
	if target_registry.size() < target_count:
		var new_positions = _find_empty_positions(1, 8.0, 22.0, "T")
		if new_positions.size() > 0:
			_spawn_target_at(new_positions[0])

func _initialize_grid():
	for x in range(grid_size.x):
		grid.append([])
		for z in range(grid_size.y):
			grid[x].append("E")
	_mark_walls()

func _mark_walls():
	_mark_wall_line(Vector2i(0, 0), Vector2i(49, 0), "W")
	_mark_wall_line(Vector2i(0, 49), Vector2i(49, 49), "W")
	_mark_wall_line(Vector2i(0, 0), Vector2i(0, 49), "W")
	_mark_wall_line(Vector2i(49, 0), Vector2i(49, 49), "W")
	
	_mark_wall_line(Vector2i(8, 7), Vector2i(42, 7), "W")
	_mark_wall_line(Vector2i(8, 15), Vector2i(42, 15), "W")
	_mark_wall_line(Vector2i(8, 23), Vector2i(42, 23), "W")
	_mark_wall_line(Vector2i(8, 31), Vector2i(42, 31), "W")
	_mark_wall_line(Vector2i(8, 39), Vector2i(42, 39), "W")
	
	_mark_wall_line(Vector2i(7, 8), Vector2i(7, 42), "W")
	_mark_wall_line(Vector2i(15, 8), Vector2i(15, 42), "W")
	_mark_wall_line(Vector2i(23, 8), Vector2i(23, 42), "W")
	_mark_wall_line(Vector2i(31, 8), Vector2i(31, 42), "W")
	_mark_wall_line(Vector2i(39, 8), Vector2i(39, 42), "W")

func _mark_wall_line(from: Vector2i, to: Vector2i, cell_char: String):
	for x in range(min(from.x, to.x), max(from.x, to.x) + 1):
		for z in range(min(from.y, to.y), max(from.y, to.y) + 1):
			if x >= 0 and x < grid_size.x and z >= 0 and z < grid_size.y:
				grid[x][z] = cell_char

func _grid_to_world(grid_pos: Vector2i, y: float = 0.0) -> Vector3:
	var wx = (grid_pos.x - grid_size.x * 0.5) * cell_size
	var wz = (grid_pos.y - grid_size.y * 0.5) * cell_size
	return Vector3(wx, y, wz)

func _find_empty_positions(count: int, min_dist: float = 8.0, max_dist: float = 22.0, label: String = "T") -> Array:
	var positions: Array = []
	var attempts = 0
	
	while positions.size() < count and attempts < 200:
		var gx = randi() % grid_size.x
		var gz = randi() % grid_size.y
		attempts += 1
		
		if grid[gx][gz] == "E":
			var dist = Vector2(gx - 25, gz - 25).length()
			if dist > min_dist and dist < max_dist:
				positions.append(Vector2i(gx, gz))
				grid[gx][gz] = label
	
	return positions

func _spawn_targets():
	for i in range(target_count):
		var positions = _find_empty_positions(1, 8.0, 22.0, "T")
		if positions.size() > 0:
			_spawn_target_at(positions[0])

func _spawn_target_at(grid_pos: Vector2i):
	var world_pos = _grid_to_world(grid_pos, 0.0)
	var target = target_scene.instantiate()
	target.position = world_pos
	target.target_grid_pos = grid_pos
	add_child(target)
	target_registry[target] = grid_pos

func _spawn_initial_zombies():
	for i in range(max_zombies):
		var positions = _find_empty_positions(1, 10.0, 24.0, "Z")
		if positions.size() > 0:
			_spawn_zombie_at(positions[0])

func _spawn_zombie_at(grid_pos: Vector2i):
	var world_pos = _grid_to_world(grid_pos, 0.0)
	var zombie = zombie_scene.instantiate()
	zombie.position = world_pos
	add_child(zombie)
	zombie_registry[zombie] = grid_pos
