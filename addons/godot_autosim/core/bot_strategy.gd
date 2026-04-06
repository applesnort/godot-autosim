## Base class for bot decision-making strategies.
##
## Extend this class and implement choose_action() to create a bot
## that plays your game. Different strategies simulate different
## player skill levels or playstyles.
class_name AutoSimBotStrategy
extends RefCounted


## Called at the start of each new game run. Override to reset any
## internal state your strategy tracks across turns.
func reset() -> void:
	pass


## Choose an action from the available actions given the current game state.
## [param state]: The current game state (opaque, from your GameAdapter).
## [param available_actions]: Array of actions returned by GameAdapter.get_available_actions().
## [returns]: One of the available actions, or null to pass/end turn.
func choose_action(state: Variant, available_actions: Array) -> Variant:
	push_error("AutoSimBotStrategy.choose_action() not implemented")
	return null
