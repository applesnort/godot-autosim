## Async simulation runner for games with coroutine-based game loops.
##
## Use this when your game adapter extends AutoSimAsyncGameAdapter.
## Must be added to the scene tree (add_child) since async adapters
## may need get_tree() for their coroutines.
##
## Usage:
##   var runner := AutoSimAsyncRunner.new()
##   add_child(runner)
##   var report := await runner.run(config)
class_name AutoSimAsyncRunner
extends Node


func run(config: AutoSimConfig) -> AutoSimBalanceReport:
	var report := AutoSimBalanceReport.new()
	report.metadata = config.metadata
	report.config_summary = {
		"iterations": config.iterations,
		"max_turns": config.max_turns,
		"rng_seed": config.rng_seed,
		"async": true,
	}

	var base_seed := config.rng_seed if config.rng_seed >= 0 else randi()

	for i in config.iterations:
		var run_seed := base_seed + i if config.rng_seed >= 0 else randi()
		seed(run_seed)

		var result := await _run_single(config, run_seed)
		report.runs.append(result)

	return report


func _run_single(config: AutoSimConfig, run_seed: int) -> AutoSimRunResult:
	var adapter: AutoSimAsyncGameAdapter = config.game_adapter as AutoSimAsyncGameAdapter
	var state: Variant = adapter.create_initial_state()

	for bot in config.strategies.values():
		if bot is AutoSimBotStrategy:
			bot.reset()

	var turn := 0
	while not adapter.is_game_over(state) and turn < config.max_turns:
		var role := adapter.get_current_role(state)
		var bot: AutoSimBotStrategy = config.strategies.get(role)

		if bot == null:
			break

		var actions := adapter.get_available_actions(state)
		if actions.is_empty():
			break

		var action = bot.choose_action(state, actions)
		if action == null:
			break

		state = await adapter.apply_action_async(state, action)
		turn += 1

	var result := AutoSimRunResult.new()
	result.winner = adapter.get_winner(state)
	result.turns = turn
	result.seed_used = run_seed
	result.metrics = adapter.get_run_metrics(state)
	result.metrics["turns"] = turn

	return result
