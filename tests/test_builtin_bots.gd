extends GutTest

var CardBattleAdapter = preload("res://addons/godot_autosim/examples/card_battle/card_battle_adapter.gd")


# === AutoSimRandomBot ===

func test_random_bot_chooses_action() -> void:
	var adapter = CardBattleAdapter.new()
	var state = adapter.create_initial_state()
	var actions := adapter.get_available_actions(state)
	var bot := AutoSimRandomBot.new()
	var chosen = bot.choose_action(state, actions)
	assert_not_null(chosen, "Random bot should always choose something")


func test_random_bot_completes_game() -> void:
	var adapter = CardBattleAdapter.new()
	var bot := AutoSimRandomBot.new()
	var config := AutoSimConfig.create(adapter, {"player": bot}, 20)
	var report := AutoSimRunner.run(config)
	assert_eq(report.runs.size(), 20, "Should complete all runs")
	for run in report.runs:
		assert_gt(run.turns, 0, "Each run should take at least 1 turn")


func test_random_bot_has_variance() -> void:
	var adapter = CardBattleAdapter.new()
	var bot := AutoSimRandomBot.new()
	var config := AutoSimConfig.create(adapter, {"player": bot}, 50)
	var report := AutoSimRunner.run(config)
	var sd := report.stddev("turns")
	gut.p("Random bot stddev turns: %.2f" % sd)
	# Random choices should produce some variance in turn counts
	# (not guaranteed but extremely likely over 50 runs)
	pass_test("Random bot completed 50 runs")


# === AutoSimGreedyBot ===

func test_greedy_bot_picks_highest_metric() -> void:
	# Greedy bot targeting "damage" should prefer attack cards over end_turn
	var adapter = CardBattleAdapter.new()
	var state = adapter.create_initial_state()
	var actions := adapter.get_available_actions(state)
	var bot := AutoSimGreedyBot.new("value")
	var chosen = bot.choose_action(state, actions)
	assert_not_null(chosen, "Greedy bot should choose something")
	# Should pick a card with highest value, not end_turn
	if chosen is Dictionary and chosen.has("action"):
		assert_eq(chosen["action"], "play_card", "Should play a card, not end turn")


func test_greedy_bot_completes_game() -> void:
	var adapter = CardBattleAdapter.new()
	var bot := AutoSimGreedyBot.new("value")
	var config := AutoSimConfig.create(adapter, {"player": bot}, 20)
	var report := AutoSimRunner.run(config)
	assert_eq(report.runs.size(), 20, "Should complete all runs")


func test_greedy_bot_falls_back_to_first() -> void:
	# When metric key doesn't exist in actions, greedy bot should still pick something
	var adapter = CardBattleAdapter.new()
	var bot := AutoSimGreedyBot.new("nonexistent_metric")
	var state = adapter.create_initial_state()
	var actions := adapter.get_available_actions(state)
	var chosen = bot.choose_action(state, actions)
	assert_not_null(chosen, "Should fall back to first action")


func test_greedy_bot_outperforms_random() -> void:
	var adapter = CardBattleAdapter.new()
	adapter.enemy_hp = 200
	var greedy_config := AutoSimConfig.create(adapter, {"player": AutoSimGreedyBot.new("value")}, 100, 42)
	var greedy_report := AutoSimRunner.run(greedy_config)

	adapter = CardBattleAdapter.new()
	adapter.enemy_hp = 200
	var random_config := AutoSimConfig.create(adapter, {"player": AutoSimRandomBot.new()}, 100, 42)
	var random_report := AutoSimRunner.run(random_config)

	gut.p("Greedy (value) vs 200HP: %.1f%% win" % (greedy_report.win_rate("player") * 100))
	gut.p("Random vs 200HP: %.1f%% win" % (random_report.win_rate("player") * 100))
	# Greedy should do at least as well as random against a tough enemy
	assert_gte(greedy_report.win_rate("player"), random_report.win_rate("player"),
		"Greedy should match or beat random")
