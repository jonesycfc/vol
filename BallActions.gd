class_name BallActions
extends Node

@onready var _pawn: PawnClass = $"../.."
@onready var _action_base: HitActionBase = $"HitActionBase"
@onready var _short: ShortSpike = $"HitActionBase/SpikeAction"
@onready var _receive: ReceiveAction = $"HitActionBase/ReceiveAction"
@onready var _movement: PawnMovement = $"../PawnMovement"
@onready var _del: ActionDelegator = $"../"
@onready var _hit_selection: HitSelection = $"../PawnChoices/HitSelection"
@onready var _choices: PawnChoices = $"../PawnChoices"

@export_category("Ball Contact")
## Used only when the action definition has not been assigned.
@export var contact_distance: float = 1.0
@export var max_vertical_speed: float = 25.0

@export_category("Debug")
@export var debug_enabled: bool = false

@export_category("Shot")
@export var debug_target: bool = false

var _ball: BallScriptAnima
var _target_found: bool = false
var _shot_target: Vector3 = Vector3.ZERO
var _active_is_receive: bool = false

func _ready() -> void:
	_short.contact_reached.connect(_on_contact_reached)
	_receive.contact_reached.connect(_on_receive_contact_reached)

func tick(_delta: float) -> void:
	if not is_instance_valid(_ball) or _target_found:
		return
	try_contact_ball()

func set_ball(ball: BallScriptAnima) -> void:
	_ball = ball
	_action_base.set_ball(ball)
	_target_found = false

func is_action_active() -> bool:
	return _target_found

func try_contact_ball() -> void:
	if not is_instance_valid(_ball) or _target_found:
		return
	if MatchKeeper.get_team_in_possession() != _pawn.get_team():
		return
	# The coordinator chooses one teammate to attempt the contact.
	if _hit_selection.get_designated_receiver() != _pawn:
		return
	if MatchKeeper.get_team_touches_used(_pawn.get_team()) >= MatchKeeper.MAX_TEAM_CONTACTS:
		return
	if _hit_selection.current_action in [Enums.HitAction.NONE, Enums.HitAction.SUPPORT]:
		return

	# Receive/dig has its own animation timing; other actions currently use the
	# existing spike driver until their dedicated drivers are added.
	var use_receive := _hit_selection.current_action == Enums.HitAction.RECEIVE
	var definition: HitActionDefinition = _receive.definition if use_receive else _short.definition
	var contact_time: float = _receive.get_contact_time() if use_receive else _short.get_contact_time()
	var allowed_contact_distance := (
		definition.contact_distance if definition != null else contact_distance
	)
	var allowed_vertical_speed := (
		definition.max_vertical_speed if definition != null else max_vertical_speed
	)

	# Predict the ball at the action's contact moment. The receive contact point
	# is a configurable local-space estimate; spike uses its jump arc.
	var ball_position: Vector3 = _ball.get_position_at_time(contact_time)
	var ball_velocity: Vector3 = _ball.get_velocity_at_time(contact_time)
	var contact_position: Vector3
	if use_receive:
		contact_position = _receive.get_predicted_contact_position()
	else:
		var time_after_takeoff := maxf(contact_time - _short.get_takeoff_time(), 0.0)
		var gravity := _pawn.gravity
		var jump_height := maxf(
			_short.get_jump_velocity() * time_after_takeoff
			- 0.5 * gravity * time_after_takeoff * time_after_takeoff,
			0.0
		)
		contact_position = _short.get_contact_position() + Vector3.UP * jump_height

	var contact_error: float = ball_position.distance_to(contact_position)

	if debug_enabled:
		print("Predicted ball position: ", ball_position)
		print("Expected contact position: ", contact_position)
		print("Contact distance: ", contact_error)
		print("Predicted vertical speed: ", ball_velocity.y)
		print("Ball current position: ", _ball.global_position)
		print("Ball current velocity: ", _ball.linear_velocity)
		print("Contact time: ", contact_time)

	# Check whether the pawn can reach the contact point.
	if not can_reach_contact_position(
		contact_position,
		contact_time
	):
		_debug_rejection("pawn cannot reach contact point")
		return

	# Allow contact within the configured radius.
	if contact_error > allowed_contact_distance:
		_debug_rejection("predicted ball is outside contact range")
		return

	# Reject trajectories that are too fast vertically.
	if absf(ball_velocity.y) > allowed_vertical_speed:
		_debug_rejection("ball is moving too quickly")
		return

	if use_receive:
		_start_receive()
	else:
		_start_spike()

func can_reach_contact_position(
	target_position: Vector3,
	time_available: float
) -> bool:
	var offset: Vector3 = target_position - _pawn.global_position
	offset.y = 0.0

	var distance: float = offset.length()
	var max_distance: float = (
		_movement.move_speed * time_available
	)

	var definition: HitActionDefinition = (
		_receive.definition
		if _hit_selection.current_action == Enums.HitAction.RECEIVE
		else _short.definition
	)
	var allowed_contact_distance := (
		definition.contact_distance if definition != null else contact_distance
	)
	return distance <= max_distance + allowed_contact_distance

func _start_spike() -> void:
	# Choose the intended landing point before the animation starts. The
	# target is clamped to the court and stays fixed for this contact.
	# The current driver is a spike, so use the spike Resource for attacks.
	# Other action types retain their legacy target rules until their own
	# animation drivers are added.
	if (
		_short.definition != null
		and _hit_selection.current_action == Enums.HitAction.ATTACK
	):
		_shot_target = _choices.choose_target_for_definition(_short.definition)
	else:
		_shot_target = _choices.choose_target(_hit_selection.current_action)
	if debug_target or debug_enabled:
		print("Chosen shot target: ", _shot_target, " action: ", _hit_selection.current_action)

	if not _action_base.start_action():
		return

	_short.jump()
	_target_found = true

func _start_receive() -> void:
	print("pawn location", _pawn.position)
	print("ball location", _ball.position)
	
	_shot_target = _choices.choose_target_for_definition(_receive.definition)
	# A first contact should lift the ball toward a setter, not skim it along
	# the floor. Keep the target on our side of the court.
	_shot_target.y = _receive.definition.target_height if _receive.definition != null else 2.5
	if debug_target or debug_enabled:
		print("Chosen receive target: ", _shot_target)
	if not _action_base.start_action():
		return
	if not _receive.play():
		_action_base.finish_action()
		return
	_active_is_receive = true
	_target_found = true

func _debug_rejection(reason: String) -> void:
	if debug_enabled:
		print("Spike rejected: ", reason)

func _on_contact_reached(hit_position: Vector3) -> void:
	_resolve_contact(hit_position, _short.definition)

func _on_receive_contact_reached(hit_position: Vector3) -> void:
	_resolve_contact(hit_position, _receive.definition)

func _resolve_contact(
	hit_position: Vector3,
	definition: HitActionDefinition
) -> void:
	if not is_instance_valid(_ball):
		_finish_current_action()
		return

	var allowed_contact_distance := (
		definition.contact_distance if definition != null else contact_distance
	)
	var allowed_vertical_speed := (
		definition.max_vertical_speed if definition != null else max_vertical_speed
	)
	var distance := hit_position.distance_to(_ball.global_position)
	if distance > allowed_contact_distance:
		_debug_rejection("ball missed the actual contact window (distance %.2f)" % distance)
		_finish_current_action()
		return

	if absf(_ball.linear_velocity.y) > allowed_vertical_speed:
		_debug_rejection("ball was moving too quickly at contact")
		_finish_current_action()
		return

	if not MatchKeeper.register_team_touch(_pawn.get_team()):
		_finish_current_action()
		return

	var action: Enums.HitAction = _hit_selection.current_action
	var flight_time := _choices.get_flight_time(
		action,
		_shot_target,
		_ball.global_position
	)
	if definition != null and action == Enums.HitAction.ATTACK:
		flight_time = _choices.get_flight_time_for_definition(
			definition,
			_shot_target,
			_ball.global_position
		)

	_action_base.resolve_contact()
	_ball.apply_hit_toward(_shot_target, hit_position, flight_time)
	_hit_selection.notify_contact()
	_del.possession_update()
	_finish_current_action()

func _finish_current_action() -> void:
	_target_found = false
	_active_is_receive = false
	_action_base.finish_action()
