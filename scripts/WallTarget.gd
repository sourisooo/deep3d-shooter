extends StaticBody3D

var hp: int = 999

func hit():
	hp -= 1
	if hp <= 0:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
		tween.tween_callback(queue_free)
