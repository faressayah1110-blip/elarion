class_name CombatComponent
extends Node

@export var attack_range: float = 2.0
@export var attack_damage: int = 10
@export var heavy_strike_damage: int = 25
@export var charge_distance: float = 5.0
@export var charge_speed: float = 20.0

var basic_attack_cd := AbilityCooldown.new(0.8)
var charge_cd := AbilityCooldown.new(6.0)
var heavy_strike_cd := AbilityCooldown.new(8.0)
var block_cd := AbilityCooldown.new(4.0)
var is_blocking: bool = false

func _process(delta: float) -> void:
	basic_attack_cd.tick(delta)
	charge_cd.tick(delta)
	heavy_strike_cd.tick(delta)
	block_cd.tick(delta)

func try_basic_attack(target: Node) -> bool:
	if not basic_attack_cd.is_ready():
		return false
	basic_attack_cd.use()
	_deal_damage(target, attack_damage)
	return true

func try_charge(character: CharacterBody3D, facing_direction: Vector3) -> bool:
	if not charge_cd.is_ready():
		return false
	charge_cd.use()
	var travel_time := charge_distance / charge_speed
	var tween := character.create_tween()
	tween.tween_property(
		character, "position",
		character.position + facing_direction.normalized() * charge_distance,
		travel_time
	)
	return true

func try_heavy_strike(target: Node) -> bool:
	if not heavy_strike_cd.is_ready():
		return false
	heavy_strike_cd.use()
	_deal_damage(target, heavy_strike_damage)
	return true

func try_block() -> bool:
	if not block_cd.is_ready():
		return false
	block_cd.use()
	is_blocking = true
	return true

func _deal_damage(target: Node, amount: int) -> void:
	if target.has_method("get_health") and not is_blocking:
		var target_health: Health = target.get_health()
		target_health.apply_damage(amount)
