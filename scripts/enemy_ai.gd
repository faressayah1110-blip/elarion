class_name EnemyAI
extends CharacterBody3D

enum State { IDLE, CHASE, ATTACK }

@export var aggro_range: float = 8.0
@export var attack_range: float = 2.0
@export var move_speed: float = 4.0

var health := Health.new()
var state: State = State.IDLE
var target: Node3D = null

@onready var combat: CombatComponent = $CombatComponent

static func next_state(current: State, distance_to_target: float, aggro: float, attack: float) -> State:
	if current == State.IDLE:
		return State.CHASE if distance_to_target <= aggro else State.IDLE
	if distance_to_target > aggro:
		return State.IDLE
	if distance_to_target <= attack:
		return State.ATTACK
	return State.CHASE

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority() or target == null:
		return
	var distance := global_position.distance_to(target.global_position)
	state = next_state(state, distance, aggro_range, attack_range)
	if state == State.CHASE:
		var direction := (target.global_position - global_position).normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		move_and_slide()
	elif state == State.ATTACK:
		velocity = Vector3.ZERO
		combat.try_basic_attack(target)

func get_health() -> Health:
	return health
