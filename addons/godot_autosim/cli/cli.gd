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
extends SceneTree


func _init() -> void:
	var args := _parse_args()

	if args.has("help"):
		_print_help()
		quit(0)
		return

	var adapter_path: String = args.get("adapter", "")
	var strategy_path: String = args.get("strategy", "")
	var iterations: int = int(args.get("iterations", "100"))
	var rng_seed: int = int(args.get("seed", "-1"))
	var max_turns: int = int(args.get("max-turns", "1000"))
	var output_path: String = args.get("output", "")

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

	var config := AutoSimConfig.create(adapter, strategies, iterations, rng_seed, max_turns)

	print("godot-autosim | %d iterations | adapter: %s | strategy: %s" % [
		iterations, adapter_path, strategy_path,
	])
	print("Running...")

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

	quit(0)


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
	print("  --iterations=<n>     Number of simulations (default: 100)")
	print("  --seed=<n>           RNG seed for reproducibility (default: -1 = random)")
	print("  --max-turns=<n>      Max turns per run (default: 1000)")
	print("  --output=<path>      Save JSON report to file")
	print("  --help               Show this message")
