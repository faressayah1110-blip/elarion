class_name Health
extends RefCounted

var max_health: int = 100
var current: int = 100

func apply_damage(amount: int) -> void:
	current = max(0, current - amount)

func is_dead() -> bool:
	return current <= 0
