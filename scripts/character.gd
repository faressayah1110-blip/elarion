class_name Character
extends CharacterBody3D

@export var move_speed: float = 6.0

var health := Health.new()

@onready var camera_pivot: Node3D = $CameraPivot
@onready var combat: CombatComponent = $CombatComponent

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var cam_basis := camera_pivot.global_transform.basis
	var direction := (cam_basis.x * input_dir.x + cam_basis.z * input_dir.y).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	move_and_slide()

func get_health() -> Health:
	return health
