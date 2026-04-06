## Orchestrates batch game simulations.
##
## Takes a SimConfig and runs N iterations of the game, collecting
## results into a BalanceReport.
##
## Usage:
##   var config := AutoSimConfig.create(my_adapter, {"player": my_bot}, 1000)
##   var report := AutoSimRunner.run(config)
##   print(report.summary())
class_name AutoSimRunner
extends RefCounted


static func run(config: AutoSimConfig) -> AutoSimBalanceReport:
	var report := AutoSimBalanceReport.new()
	report.metadata = config.metadata
	report.config_summary = {
		"iterations": config.iterations,
		"max_turns": config.max_turns,
		"rng_seed": config.rng_seed,
		"strategies": _strategy_names(config.strategies),
	}

	var base_seed := config.rng_seed if config.rng_seed >= 0 else randi()

	for i in config.iterations:
		var run_seed := base_seed + i if config.rng_seed >= 0 else randi()
		seed(run_seed)

		var result := _run_single(config, run_seed)
		report.runs.append(result)

	return report


static func _run_single(config: AutoSimConfig, run_seed: int) -> AutoSimRunResult:
	var adapter := config.game_adapter
	var state: Variant = adapter.create_initial_state()

	for bot in config.strategies.values():
		if bot is AutoSimBotStrategy:
			bot.reset()

	var turn := 0
	while not adapter.is_game_over(state) and turn < config.max_turns:
		var role := adapter.get_current_role(state)
		var bot: AutoSimBotStrategy = config.strategies.get(role)

		if bot == null:
			push_warning("AutoSimRunner: no strategy for role '%s', skipping" % role)
			break

		var actions := adapter.get_available_actions(state)
		if actions.is_empty():
			break

		var action = bot.choose_action(state, actions)
		if action == null:
			break

		state = adapter.apply_action(state, action)
		turn += 1

	var result := AutoSimRunResult.new()
	result.winner = adapter.get_winner(state)
	result.turns = turn
	result.seed_used = run_seed
	result.metrics = adapter.get_run_metrics(state)
	result.metrics["turns"] = turn

	config.game_adapter.cleanup_state(state)

	return result


static func _strategy_names(strategies: Dictionary) -> Dictionary:
	var names := {}
	for role in strategies:
		var bot = strategies[role]
		names[role] = bot.get_script().get_global_name() if bot.get_script() else "unknown"
	return names
