extends GutTest

var CardBattleAdapter = preload("res://examples/card_battle/card_battle_adapter.gd")
var AggressiveBot = preload("res://examples/card_battle/aggressive_bot.gd")


func test_adapter_create_state() -> void:
	var adapter = CardBattleAdapter.new()
	var state = adapter.create_initial_state()
	assert_not_null(state, "State should not be null")
	gut.p("State type: %s" % typeof(state))
	gut.p("State: %s" % str(state))


func test_adapter_is_game_over_initial() -> void:
	var adapter = CardBattleAdapter.new()
	var state = adapter.create_initial_state()
	var over := adapter.is_game_over(state)
	gut.p("Game over on initial state: %s" % str(over))
	assert_false(over, "Game should not be over at start")


func test_adapter_get_actions() -> void:
	var adapter = CardBattleAdapter.new()
	var state = adapter.create_initial_state()
	var actions := adapter.get_available_actions(state)
	gut.p("Available actions: %d" % actions.size())
	for a in actions:
		gut.p("  %s" % str(a))
	assert_gt(actions.size(), 0, "Should have actions available")


func test_adapter_apply_action() -> void:
	var adapter = CardBattleAdapter.new()
	var state = adapter.create_initial_state()
	var actions := adapter.get_available_actions(state)
	gut.p("Actions before: %d" % actions.size())
	if actions.size() > 0:
		state = adapter.apply_action(state, actions[0])
		gut.p("Applied action: %s" % str(actions[0]))
		gut.p("Game over after action: %s" % str(adapter.is_game_over(state)))


func test_bot_chooses_action() -> void:
	var adapter = CardBattleAdapter.new()
	var state = adapter.create_initial_state()
	var actions := adapter.get_available_actions(state)
	var bot = AggressiveBot.new()
	var chosen = bot.choose_action(state, actions)
	gut.p("Bot chose: %s" % str(chosen))
	assert_not_null(chosen, "Bot should choose an action")


func test_manual_game_loop() -> void:
	var adapter = CardBattleAdapter.new()
	var state = adapter.create_initial_state()
	var bot = AggressiveBot.new()
	var turns := 0
	while not adapter.is_game_over(state) and turns < 50:
		var actions := adapter.get_available_actions(state)
		if actions.is_empty():
			gut.p("No actions at turn %d" % turns)
			break
		var action = bot.choose_action(state, actions)
		if action == null:
			gut.p("Bot returned null at turn %d" % turns)
			break
		state = adapter.apply_action(state, action)
		turns += 1
	gut.p("Game ended after %d actions, winner: '%s'" % [turns, adapter.get_winner(state)])
	assert_gt(turns, 0, "Game should take at least 1 action")
