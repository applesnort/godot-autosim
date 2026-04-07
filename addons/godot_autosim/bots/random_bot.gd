## Built-in bot that picks a random action each turn.
##
## Useful as a baseline — if random play wins too often, your game is too easy.
class_name AutoSimRandomBot
extends AutoSimBotStrategy


func choose_action(_state: Variant, available_actions: Array) -> Variant:
	if available_actions.is_empty():
		return null
	return available_actions[randi() % available_actions.size()]
