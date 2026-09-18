class_name AbilityCooldown
extends RefCounted

var duration: float
var _remaining: float = 0.0

func _init(cooldown_duration: float) -> void:
	duration = cooldown_duration

func is_ready() -> bool:
	return _remaining <= 0.0

func use() -> void:
	_remaining = duration

func tick(delta: float) -> void:
	_remaining = max(0.0, _remaining - delta)
