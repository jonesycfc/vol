class_name TestSceneAnima
extends Node3D

@onready var ball: BallScriptAnima = $BallScriptAnima

var pawns: Array[PawnClass] = []


func _ready() -> void:
	MatchKeeper.reset_match_state(Enums.Team.Home)
	collect_pawns(self)
	for pawn in pawns:
		pawn.set_ball(ball)


func collect_pawns(node: Node) -> void:
	for child in node.get_children():
		if child is PawnClass:
			pawns.append(child as PawnClass)
		collect_pawns(child)
