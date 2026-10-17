class_name PawnChoices
extends Node

## Playable court bounds for the current test scene. These can be adjusted
## in the Inspector if the court mesh or scale changes.
@export_category("Court Bounds")
@export var court_x_min: float = -9.0
@export var court_x_max: float = 9.0
@export var court_z_min: float = -9.0
@export var court_z_max: float = 9.0
@export var target_height: float = 0.25

@export_category("Target Variation")
@export var receive_depth_min: float = 3.5
@export var receive_depth_max: float = 6.5
@export var set_depth_min: float = 1.4
@export var set_depth_max: float = 2.0
@export var attack_depth_min: float = 2.0
@export var attack_depth_max: float = 8.0
@export var target_x_min: float = -7.5
@export var target_x_max: float = 7.5

@onready var _pawn: PawnClass = get_parent().get_parent()


## Resource-driven target selection. Action-specific target rules live in
## HitActionDefinition; the enum-based method below remains for legacy callers.
func choose_target_for_definition(definition: HitActionDefinition) -> Vector3:
	if definition == null:
		return choose_target(Enums.HitAction.ATTACK)

	var own_side_sign: float = -1.0 if _pawn.get_team() == Enums.Team.Home else 1.0
	var opponent_side_sign: float = -own_side_sign
	var target_x := randf_range(target_x_min, target_x_max)
	var target_z: float

	match definition.target_policy:
		HitActionDefinition.TargetPolicy.TEAMMATE:
			target_z = own_side_sign * randf_range(receive_depth_min, receive_depth_max)
		HitActionDefinition.TargetPolicy.SETTER_ZONE:
			target_z = own_side_sign * randf_range(set_depth_min, set_depth_max)
		HitActionDefinition.TargetPolicy.ATTACK_ZONE, HitActionDefinition.TargetPolicy.OPPONENT_COURT:
			target_z = opponent_side_sign * randf_range(attack_depth_min, attack_depth_max)

	return clamp_target_to_court(
		Vector3(target_x, definition.target_height, target_z)
	)


func get_flight_time_for_definition(
	definition: HitActionDefinition,
	target: Vector3,
	start: Vector3
) -> float:
	if definition == null:
		return get_flight_time(Enums.HitAction.ATTACK, target, start)

	# Longer shots naturally need more time; preferred_flight_time is the
	# configured baseline, clamped to the action's allowed range.
	var horizontal_distance := Vector2(
		target.x - start.x,
		target.z - start.z
	).length()
	var distance_adjusted_time := definition.preferred_flight_time
	if definition.kind == HitActionDefinition.Kind.SPIKE:
		distance_adjusted_time = horizontal_distance / 14.0
	elif definition.kind == HitActionDefinition.Kind.SET:
		distance_adjusted_time = horizontal_distance / 9.0
	else:
		distance_adjusted_time = horizontal_distance / 7.0

	return clampf(
		distance_adjusted_time,
		definition.minimum_flight_time,
		definition.maximum_flight_time
	)


## Select a target for the currently selected play. Every target is clamped
## to the playable court bounds and stays on the appropriate side of the net.
func choose_target(action: Enums.HitAction) -> Vector3:
	var own_side_sign: float = -1.0 if _pawn.get_team() == Enums.Team.Home else 1.0
	var opponent_side_sign: float = -own_side_sign
	var target_x := randf_range(target_x_min, target_x_max)
	var target_z: float

	match action:
		Enums.HitAction.RECEIVE, Enums.HitAction.FREE_BALL:
			target_z = own_side_sign * randf_range(
				receive_depth_min,
				receive_depth_max
			)
		Enums.HitAction.SET:
			target_z = own_side_sign * randf_range(
				set_depth_min,
				set_depth_max
			)
		_:
			# ATTACK/BLOCK fallback: send the ball into the opponent's half.
			target_z = opponent_side_sign * randf_range(
				attack_depth_min,
				attack_depth_max
			)

	return clamp_target_to_court(Vector3(target_x, target_height, target_z))


func clamp_target_to_court(target: Vector3) -> Vector3:
	target.x = clampf(target.x, court_x_min, court_x_max)
	target.z = clampf(target.z, court_z_min, court_z_max)
	target.y = target_height
	return target


func get_flight_time(action: Enums.HitAction, target: Vector3, start: Vector3) -> float:
	var horizontal_distance := Vector2(
		target.x - start.x,
		target.z - start.z
	).length()

	match action:
		Enums.HitAction.RECEIVE, Enums.HitAction.FREE_BALL:
			return clampf(horizontal_distance / 7.0, 0.8, 1.35)
		Enums.HitAction.SET:
			return clampf(horizontal_distance / 9.0, 0.6, 1.0)
		_:
			return clampf(horizontal_distance / 14.0, 0.42, 0.85)
