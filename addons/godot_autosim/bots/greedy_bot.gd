## Built-in bot that picks the action with the highest value for a given key.
##
## Usage:
##   var bot = AutoSimGreedyBot.new("value")    # picks action with highest "value" field
##   var bot = AutoSimGreedyBot.new("damage")   # picks action with highest "damage" field
##
## Actions must be Dictionaries with the target key. Actions without the key
## are deprioritized. If no action has the key, falls back to the first action.
class_name AutoSimGreedyBot
extends AutoSimBotStrategy

var _metric_key: String


func _init(metric_key: String = "value") -> void:
	_metric_key = metric_key


func choose_action(_state: Variant, available_actions: Array) -> Variant:
	var best: Variant = null
	var best_val: float = -INF

	for action in available_actions:
		if action is Dictionary and action.has(_metric_key):
			var val: float = float(action[_metric_key])
			if val > best_val:
				best_val = val
				best = action

	return best if best != null else available_actions[0]
