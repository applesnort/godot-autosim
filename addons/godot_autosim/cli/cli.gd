## CLI runner for godot-autosim.
##
## Usage:
##   godot --headless --script addons/godot_autosim/cli/cli.gd -- \
##     --adapter=res://my_adapter.gd \
##     --strategy=res://my_bot.gd \
##     --iterations=1000 \
##     --seed=42 \
##     --max-turns=500 \
##     --output=balance_report.json
##
## Sweep mode:
##   godot --headless --script addons/godot_autosim/cli/cli.gd -- \
##     --adapter=res://my_adapter.gd \
##     --strategy=res://my_bot.gd \
##     --sweep=enemy_hp:30,50,75,100,150,200 \
##     --output=sweep_report.json
extends SceneTree


func _init() -> void:
	var args := _parse_args()

	if args.has("help"):
		_print_help()
		quit(0)
		return

	var adapter_path: String = args.get("adapter", "")
	var strategy_path: String = args.get("strategy", "")
	var iterations: int = int(args.get("iterations", "200" if args.has("sweep") else "100"))
	var rng_seed: int = int(args.get("seed", "-1"))
	var max_turns: int = int(args.get("max-turns", "1000"))
	var output_path: String = args.get("output", "")
	var sweep_arg: String = args.get("sweep", "")

	if adapter_path == "":
		printerr("Error: --adapter is required. Pass --help for usage.")
		quit(1)
		return

	if strategy_path == "":
		printerr("Error: --strategy is required. Pass --help for usage.")
		quit(1)
		return

	var adapter_script = load(adapter_path)
	if adapter_script == null:
		printerr("Error: could not load adapter at '%s'" % adapter_path)
		quit(1)
		return

	var strategy_script = load(strategy_path)
	if strategy_script == null:
		printerr("Error: could not load strategy at '%s'" % strategy_path)
		quit(1)
		return

	var adapter: AutoSimGameAdapter = adapter_script.new()
	var strategy: AutoSimBotStrategy = strategy_script.new()

	var roles := adapter.get_roles()
	var strategies := {}
	for role in roles:
		strategies[role] = strategy

	if sweep_arg != "":
		_run_sweep(adapter, strategies, roles, sweep_arg, iterations, rng_seed, output_path)
	else:
		_run_single(adapter, strategies, roles, iterations, rng_seed, max_turns, output_path, adapter_path, strategy_path)

	quit(0)


func _run_single(
	adapter: AutoSimGameAdapter,
	strategies: Dictionary,
	roles: Array[String],
	iterations: int,
	rng_seed: int,
	max_turns: int,
	output_path: String,
	adapter_path: String,
	strategy_path: String,
) -> void:
	print("godot-autosim | %d iterations | adapter: %s | strategy: %s" % [
		iterations, adapter_path, strategy_path,
	])
	print("Running...")

	var config := AutoSimConfig.create(adapter, strategies, iterations, rng_seed, max_turns)
	var report := AutoSimRunner.run(config)

	print("")
	print("Results: %s" % report.summary())
	print("Win rate: %.1f%%" % (report.win_rate(roles[0] if roles.size() > 0 else "player") * 100.0))
	print("Avg turns: %.1f" % report.avg("turns"))

	if output_path != "":
		var err := report.save(output_path)
		if err == OK:
			print("Report saved to: %s" % output_path)
		else:
			printerr("Error saving report: %s" % error_string(err))


func _run_sweep(
	adapter: AutoSimGameAdapter,
	strategies: Dictionary,
	roles: Array[String],
	sweep_arg: String,
	iterations: int,
	rng_seed: int,
	output_path: String,
) -> void:
	var parsed := _parse_sweep(sweep_arg)
	if parsed.is_empty():
		printerr("Error: invalid --sweep format. Expected: --sweep=param_name:val1,val2,...")
		quit(1)
		return

	var param_name: String = parsed["param"]
	var values: Array = parsed["values"]

	print("godot-autosim sweep | %s: %s | %d iterations per step" % [
		param_name, str(values), iterations,
	])
	print("Running...")

	var result := AutoSimSweepRunner.run(adapter, strategies, param_name, values, iterations, rng_seed)

	if result.steps.is_empty():
		printerr("Error: sweep produced no results. Check that '%s' is a valid property on your adapter." % param_name)
		quit(1)
		return

	print("")
	var role: String = roles[0] if roles.size() > 0 else "player"
	print(result.table(role))

	if output_path != "":
		var err := result.save(output_path)
		if err == OK:
			print("\nReport saved to: %s" % output_path)
		else:
			printerr("Error saving report: %s" % error_string(err))


static func _parse_sweep(sweep_str: String) -> Dictionary:
	var colon := sweep_str.find(":")
	if colon < 0:
		return {}
	var param := sweep_str.substr(0, colon)
	var values_str := sweep_str.substr(colon + 1)
	var values: Array[float] = []
	for v in values_str.split(","):
		values.append(float(v.strip_edges()))
	return {param = param, values = values}


func _parse_args() -> Dictionary:
	var result := {}
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--"):
			var stripped := arg.substr(2)
			var eq_pos := stripped.find("=")
			if eq_pos >= 0:
				result[stripped.substr(0, eq_pos)] = stripped.substr(eq_pos + 1)
			else:
				result[stripped] = "true"
	return result


func _print_help() -> void:
	print("godot-autosim — Automated game simulation for Godot 4.6+")
	print("")
	print("Usage:")
	print("  godot --headless --script addons/godot_autosim/cli/cli.gd -- [options]")
	print("")
	print("Required:")
	print("  --adapter=<path>     Path to your GameAdapter script (res://...)")
	print("  --strategy=<path>    Path to your BotStrategy script (res://...)")
	print("")
	print("Optional:")
	print("  --iterations=<n>     Number of simulations (default: 100, or 200 in sweep mode)")
	print("  --seed=<n>           RNG seed for reproducibility (default: -1 = random)")
	print("  --max-turns=<n>      Max turns per run (default: 1000)")
	print("  --output=<path>      Save JSON report to file")
	print("  --help               Show this message")
	print("")
	print("Sweep mode:")
	print("  --sweep=<param>:<v1>,<v2>,...  Vary an adapter property across values")
	print("")
	print("  Example: --sweep=enemy_hp:30,50,75,100,150,200")
	print("  Runs a full batch at each value and prints a comparison table.")
