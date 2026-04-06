## Configuration for a simulation batch.
class_name AutoSimConfig
extends RefCounted

## The game adapter bridging your game to the framework.
var game_adapter: AutoSimGameAdapter

## Map of role_name -> AutoSimBotStrategy.
## For single-player games: {"player": my_bot}
## For two-player games: {"player_1": aggressive_bot, "player_2": defensive_bot}
var strategies: Dictionary = {}

## Number of simulation iterations to run.
var iterations: int = 100

## RNG seed. -1 = random seed per run (non-reproducible).
## Any other value = deterministic (same seed sequence for all runs).
var rng_seed: int = -1

## Maximum turns per run before force-ending (safety valve against infinite loops).
var max_turns: int = 1000

## Arbitrary metadata attached to the report (e.g., deck name, version tag).
var metadata: Dictionary = {}


static func create(
	adapter: AutoSimGameAdapter,
	bot_strategies: Dictionary,
	num_iterations: int = 100,
	seed_value: int = -1,
	turn_limit: int = 1000,
) -> AutoSimConfig:
	var config := AutoSimConfig.new()
	config.game_adapter = adapter
	config.strategies = bot_strategies
	config.iterations = num_iterations
	config.rng_seed = seed_value
	config.max_turns = turn_limit
	return config
