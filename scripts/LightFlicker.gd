extends OmniLight3D

@export var min_energy: float = 0.1
@export var max_energy: float = 0.8
@export var flicker_speed: float = 8.0

var base_energy: float
var time: float = 0.0

func _ready():
	base_energy = light_energy

func _process(delta):
	time += delta * flicker_speed
	light_energy = base_energy * (min_energy + (max_energy - min_energy) * abs(sin(time)))
