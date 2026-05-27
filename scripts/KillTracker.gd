extends Node

# Global kill tracker - accessible from anywhere
static var kills: int = 0

static func register_kill() -> bool:
	# Returns true if this was a special kill (every 3rd)
	kills += 1
	return kills % 3 == 0
