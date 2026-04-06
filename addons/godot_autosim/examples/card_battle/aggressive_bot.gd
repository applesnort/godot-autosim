## Example bot: plays highest-damage card first, blocks only when out of attacks.
extends AutoSimBotStrategy


func choose_action(state: Variant, available_actions: Array) -> Variant:
	var best_attack: Variant = null
	var best_attack_value := -1

	var best_block: Variant = null
	var best_block_value := -1

	for action in available_actions:
		var act: Dictionary = action
		if act["action"] == "play_card":
			var card: Dictionary = act["card"]
			if card["type"] == "attack" and card["value"] > best_attack_value:
				best_attack = action
				best_attack_value = card["value"]
			elif card["type"] == "block" and card["value"] > best_block_value:
				best_block = action
				best_block_value = card["value"]

	if best_attack != null:
		return best_attack
	if best_block != null:
		return best_block

	# End turn when nothing playable
	for action in available_actions:
		if (action as Dictionary)["action"] == "end_turn":
			return action
	return null
