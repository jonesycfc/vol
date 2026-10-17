class_name PawnAnimationScene
extends Node3D

signal animation_finished(anim_name: StringName)

@onready var _pawn: CharacterBody3D = $"../"
@onready var _skel: Skeleton3D = $Armature/Skeleton3D
@onready var _animation_player: AnimationPlayer = $Armature/AnimationPlayer
@onready var _tree: AnimationTree = $Armature/AnimationTree
@onready var _contact_point: Marker3D = \
	$Armature/Skeleton3D/R_HandBoneAttachment3D/ContactPoint


func _ready() -> void:
	_animation_player.animation_finished.connect(
		_on_animation_finished
	)


func play_anim(anim_name: StringName, speed_scale: float = 1.0) -> void:
	_tree.active = false

	_animation_player.speed_scale = speed_scale
	_animation_player.play(anim_name)

func get_animation_position() -> float:
	return _animation_player.current_animation_position


func get_anim_tree() -> AnimationTree:
	return _tree


func get_skeleton() -> Skeleton3D:
	return _skel


func get_animation_player() -> AnimationPlayer:
	return _animation_player


func _on_animation_finished(anim_name: StringName) -> void:
	animation_finished.emit(anim_name)
	
func get_current_animation() -> Animation:
	if _animation_player.current_animation == StringName():
		return null

	return _animation_player.get_animation(
		_animation_player.current_animation
	)

func get_contact_point() -> Marker3D:
	return _contact_point
	
func debug_print_contact_position() -> void:
	print("=== SPIKE CONTACT DEBUG ===")
	print("Animation: ", _animation_player.current_animation)
	print("Animation time: ", _animation_player.current_animation_position)

	print("Hand position (global): ", _contact_point.global_position)

	print(
		"Hand position in pawn-local space: ",
		_pawn.global_transform.affine_inverse()
			* _contact_point.global_position
	)

	print("Pawn position: ", _pawn.global_position)
	print("===========================")

func get_contact_position() -> Vector3:
	return _contact_point.global_position

func get_hand_position_in_pawn_space() -> Vector3:
	return (
		_pawn.global_transform.affine_inverse()
		* _contact_point.global_position
	)
