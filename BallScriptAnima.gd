class_name BallScriptAnima
extends RigidBody3D

@onready var _properties: BallProperties = $Properties
@onready var _contact: BallContact = $Contact

@export var size: Vector3 = Vector3.ONE:
	set(value):
		size = value

		if is_node_ready():
			_properties._update_children()


func _ready() -> void:
	_properties.size = size
	_properties._update_children()

func get_position_at_time(time: float) -> Vector3:
	var gravity := Vector3.DOWN * float(
		ProjectSettings.get_setting("physics/3d/default_gravity")
	)

	return global_position \
		+ linear_velocity * time \
		+ 0.5 * gravity * time * time

func get_velocity_at_time(time: float) -> Vector3:
	var gravity := Vector3.DOWN * float(
		ProjectSettings.get_setting("physics/3d/default_gravity")
	)

	return linear_velocity + gravity * time

func get_landing_position() -> Vector3:
	var gravity: float = float(
		ProjectSettings.get_setting("physics/3d/default_gravity")
	)

	var start_position := global_position
	var start_velocity := linear_velocity

	var a := -0.5 * gravity
	var b := start_velocity.y
	var c := start_position.y

	var discriminant := (b * b) - (4.0 * a * c)

	if discriminant < 0.0:
		return start_position

	var root := sqrt(discriminant)

	var t1 := (-b + root) / (2.0 * a)
	var t2 := (-b - root) / (2.0 * a)

	var landing_time = max(t1, t2)

	if landing_time <= 0.0:
		return start_position

	var landing_position :Vector3 = get_position_at_time(landing_time)
	landing_position.y = 0.0

	return landing_position

func apply_hit(impulse: Vector3, hit_position: Vector3) -> void:
	_contact.apply_hit(impulse, hit_position)


## Applies the impulse needed to send the ball toward a chosen court target.
## The target is selected by PawnChoices before contact; this method only
## computes and applies the resulting trajectory at the actual contact.
func apply_hit_toward(
	target_position: Vector3,
	hit_position: Vector3,
	flight_time: float = 0.7
) -> void:
	var duration := maxf(flight_time, 0.1)
	var start_position := global_position
	var target := target_position
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))

	var desired_velocity := Vector3(
		(target.x - start_position.x) / duration,
		(target.y - start_position.y + 0.5 * gravity * duration * duration) / duration,
		(target.z - start_position.z) / duration
	)
	var impulse := (desired_velocity - linear_velocity) * mass
	_contact.apply_hit(impulse, hit_position)
	sleeping = false
