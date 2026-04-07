## Runs a parameter sweep — same game, same seed, varying one parameter.
##
## Usage:
##   var result = AutoSimSweepRunner.run(
##       adapter, {"player": bot}, "enemy_hp", [30, 50, 75, 100, 150, 200])
##   print(result.table())
##   print(result.find_threshold("player", 0.5))
class_name AutoSimSweepRunner
extends RefCounted


static func run(
	adapter: AutoSimGameAdapter,
	strategies: Dictionary,
	param_name: String,
	values: Array,
	iterations: int = 200,
	rng_seed: int = -1,
) -> AutoSimSweepResult:
	var result := AutoSimSweepResult.new()
	result.param_name = param_name
	result.iterations_per_step = iterations

	if not param_name in adapter.get_property_list().map(func(p): return p["name"]):
		push_warning("AutoSimSweepRunner: adapter has no property '%s'" % param_name)
		return result

	var base_seed: int = rng_seed if rng_seed >= 0 else randi()
	result.seed_used = base_seed

	for value in values:
		adapter.set(param_name, value)
		var config := AutoSimConfig.create(adapter, strategies, iterations, base_seed)
		var report := AutoSimRunner.run(config)
		result.steps.append({value = float(value), report = report})

	return result
