## Result of a single simulation run.
class_name AutoSimRunResult
extends RefCounted

var winner: String = ""
var turns: int = 0
var metrics: Dictionary = {}
var seed_used: int = 0


func to_dict() -> Dictionary:
	return {
		"winner": winner,
		"turns": turns,
		"metrics": metrics,
		"seed": seed_used,
	}
