class_name ReceiveAction
extends Node

## Low-pass / dig driver. Contact timing is derived from the imported animation's
## actual length so it doesn't depend on a guessed frame count.
signal contact_reached(hit_position: Vector3)

@export var definition: HitActionDefinition
@export_range(0.1, 0.95, 0.01) var contact_fraction: float = 0.72
## Approximate contact point in pawn-local space, used only for preflight prediction.
@export var predicted_contact_offset: Vector3 = Vector3(0.0, 0.75, -0.35)

@onready var _pawn: PawnClass = get_node("../../../..")
@onready var _delegator: ActionDelegator = get_node("../../..")

var _checking_contact: bool = false
var _impact_shown: bool = false
var _contact_time: float = 0.0

func _ready() -> void:
	if definition == null:
		push_warning("ReceiveAction has no HitActionDefinition assigned.")
	elif not definition.is_valid_definition():
		push_warning("ReceiveAction's HitActionDefinition has invalid settings.")

func get_contact_time() -> float:
	return _contact_time if _contact_time > 0.0 else _get_animation_length() * contact_fraction

func get_predicted_contact_position() -> Vector3:
	return _pawn.global_transform * predicted_contact_offset


func play() -> bool:
	if definition == null or definition.animation_name.is_empty():
		push_warning("ReceiveAction cannot play: animation definition is missing.")
		return false

	var player: AnimationPlayer = _pawn.pawn_animation.get_animation_player()

	if not player.has_animation(definition.animation_name):
		push_warning(
			"Receive animation not found: %s" % definition.animation_name
		)
		return false

	var length: float = player.get_animation(
		definition.animation_name
	).length

	if length <= 0.0:
		push_warning(
			"Receive animation has no duration: %s" % definition.animation_name
		)
		return false

	# Prepare contact tracking before starting playback.
	_contact_time = length * clampf(contact_fraction, 0.1, 0.95)
	_checking_contact = true
	_impact_shown = false

	# Start the animation once.
	_pawn.pawn_animation.play_anim(definition.animation_name)

	print(
		"RECEIVE REQUESTED: ", definition.animation_name,
		" | PLAYER: ", player.current_animation,
		" | POSITION: ", player.current_animation_position,
		" | TREE ACTIVE: ", _pawn.pawn_animation.get_anim_tree().active
	)

	# Diagnose playback on the next frame without awaiting here.
	_check_animation_next_frame.call_deferred(player)

	return true


func _check_animation_next_frame(player: AnimationPlayer) -> void:
	await get_tree().process_frame

	if not is_instance_valid(player):
		return

	print(
		"RECEIVE NEXT FRAME: ", player.current_animation,
		" | POSITION: ", player.current_animation_position,
		" | TREE ACTIVE: ", _pawn.pawn_animation.get_anim_tree().active
	)


func _get_animation_length() -> float:
	if definition == null:
		return 0.0
	var player := _pawn.pawn_animation.get_animation_player()
	if not player.has_animation(definition.animation_name):
		return 0.0
	return player.get_animation(definition.animation_name).length

func _physics_process(_delta: float) -> void:
	if not _checking_contact or _impact_shown:
		return
	if _pawn.pawn_animation.get_animation_position() < get_contact_time():
		return

	var hit_position: Vector3 = _pawn.pawn_animation.get_contact_position()
	contact_reached.emit(hit_position)
	_delegator.show_impact_sprite(hit_position)
	_impact_shown = true
	_checking_contact = false
