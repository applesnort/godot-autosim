## Example bot: plays random available actions. Baseline for skill expression measurement.
extends AutoSimBotStrategy


func choose_action(state: Variant, available_actions: Array) -> Variant:
	if available_actions.is_empty():
		return null
	return available_actions[randi() % available_actions.size()]
