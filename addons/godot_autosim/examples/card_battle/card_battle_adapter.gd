## Example adapter: a minimal card battle game.
##
## Player has a deck of attack/block cards, fights an enemy with HP and
## a repeating attack pattern. Demonstrates the full GameAdapter interface.
##
## State is a plain Dictionary for maximum portability.
extends AutoSimGameAdapter


const STARTER_DECK := [
	{"name": "Strike", "type": "attack", "cost": 1, "value": 6},
	{"name": "Strike", "type": "attack", "cost": 1, "value": 6},
	{"name": "Strike", "type": "attack", "cost": 1, "value": 6},
	{"name": "Strike", "type": "attack", "cost": 1, "value": 6},
	{"name": "Strike", "type": "attack", "cost": 1, "value": 6},
	{"name": "Defend", "type": "block", "cost": 1, "value": 5},
	{"name": "Defend", "type": "block", "cost": 1, "value": 5},
	{"name": "Defend", "type": "block", "cost": 1, "value": 5},
	{"name": "Defend", "type": "block", "cost": 1, "value": 5},
	{"name": "Bash", "type": "attack", "cost": 2, "value": 12},
]

var enemy_hp: int = 50
var enemy_damage_pattern: Array = [8, 5, 12]


func create_initial_state() -> Variant:
	var deck := STARTER_DECK.duplicate(true)
	deck.shuffle()

	var hand: Array = []
	for i in mini(5, deck.size()):
		hand.append(deck.pop_back())

	return {
		"player_hp": 80,
		"player_max_hp": 80,
		"player_block": 0,
		"player_focus": 3,
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_hp,
		"enemy_pattern": enemy_damage_pattern.duplicate(),
		"enemy_turn_index": 0,
		"hand": hand,
		"deck": deck,
		"discard": [],
		"turn": 1,
		"result": "ongoing",
	}


func get_roles() -> Array[String]:
	return ["player"]


func get_current_role(_state: Variant) -> String:
	return "player"


func get_available_actions(state: Variant) -> Array:
	var s: Dictionary = state
	if s["result"] != "ongoing":
		return []

	var actions: Array = []
	var hand: Array = s["hand"]
	for i in hand.size():
		var card: Dictionary = hand[i]
		if card["cost"] <= s["player_focus"]:
			actions.append({"action": "play_card", "index": i, "card": card})

	actions.append({"action": "end_turn"})
	return actions


func apply_action(state: Variant, action: Variant) -> Variant:
	var s: Dictionary = state
	var act: Dictionary = action

	if act["action"] == "play_card":
		var idx: int = act["index"]
		var hand: Array = s["hand"]
		if idx < 0 or idx >= hand.size():
			return state

		var card: Dictionary = hand[idx]
		s["player_focus"] -= card["cost"]
		hand.remove_at(idx)
		(s["discard"] as Array).append(card)

		match card["type"]:
			"attack":
				s["enemy_hp"] -= card["value"]
				if s["enemy_hp"] <= 0:
					s["result"] = "won"
			"block":
				s["player_block"] += card["value"]

	elif act["action"] == "end_turn":
		_resolve_enemy_turn(s)
		if s["result"] == "ongoing":
			_start_new_turn(s)

	return state


func is_game_over(state: Variant) -> bool:
	return (state as Dictionary)["result"] != "ongoing"


func get_winner(state: Variant) -> String:
	return "player" if (state as Dictionary)["result"] == "won" else ""


func get_run_metrics(state: Variant) -> Dictionary:
	var s: Dictionary = state
	return {
		"player_hp_remaining": s["player_hp"],
		"player_hp_pct": float(s["player_hp"]) / float(s["player_max_hp"]) * 100.0,
		"enemy_hp_remaining": maxi(s["enemy_hp"], 0),
		"damage_taken": s["player_max_hp"] - s["player_hp"],
	}


func _resolve_enemy_turn(s: Dictionary) -> void:
	var pattern: Array = s["enemy_pattern"]
	var damage: int = pattern[s["enemy_turn_index"] % pattern.size()]
	s["enemy_turn_index"] += 1

	var blocked := mini(damage, s["player_block"])
	s["player_block"] -= blocked
	var through := damage - blocked
	s["player_hp"] -= through

	if s["player_hp"] <= 0:
		s["result"] = "lost"


func _start_new_turn(s: Dictionary) -> void:
	s["turn"] += 1
	s["player_focus"] = 3
	s["player_block"] = 0

	var hand: Array = s["hand"]
	var discard: Array = s["discard"]
	discard.append_array(hand)
	hand.clear()

	_draw_cards(s, 5)


func _draw_cards(s: Dictionary, count: int) -> void:
	var deck: Array = s["deck"]
	var hand: Array = s["hand"]
	var discard: Array = s["discard"]
	for _i in count:
		if deck.is_empty():
			if discard.is_empty():
				break
			deck.append_array(discard)
			discard.clear()
			deck.shuffle()
		hand.append(deck.pop_back())
