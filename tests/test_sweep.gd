extends GutTest

var CardBattleAdapter = preload("res://addons/godot_autosim/examples/card_battle/card_battle_adapter.gd")
var AggressiveBot = preload("res://addons/godot_autosim/examples/card_battle/aggressive_bot.gd")
var DefensiveBot = preload("res://addons/godot_autosim/examples/card_battle/defensive_bot.gd")
var RandomBot = preload("res://addons/godot_autosim/bots/random_bot.gd")


# === Helpers ===

func _make_mock_report(wins: int, total: int, avg_turns: float) -> AutoSimBalanceReport:
	var report := AutoSimBalanceReport.new()
	for i in total:
		var result := AutoSimRunResult.new()
		result.winner = "player" if i < wins else ""
		result.turns = int(avg_turns + (i % 3) - 1)
		result.seed_used = 42 + i
		result.metrics = {
			"turns": result.turns,
			"player_hp_remaining": 80 - (i * 2),
			"damage_taken": i * 2,
		}
		report.runs.append(result)
	return report


func _make_mock_sweep_result() -> AutoSimSweepResult:
	var result := AutoSimSweepResult.new()
	result.param_name = "enemy_hp"
	result.seed_used = 42
	result.iterations_per_step = 10
	result.steps = [
		{value = 30.0, report = _make_mock_report(10, 10, 5.0)},
		{value = 50.0, report = _make_mock_report(8, 10, 8.0)},
		{value = 75.0, report = _make_mock_report(6, 10, 10.0)},
		{value = 100.0, report = _make_mock_report(3, 10, 12.0)},
	]
	return result


# === T01: AutoSimSweepResult tests ===

func test_table_returns_formatted_string() -> void:
	var result := _make_mock_sweep_result()
	var table := result.table()
	assert_true(table.length() > 0, "Table should be non-empty")
	assert_true(table.contains("enemy_hp"), "Table should contain param name")
	assert_true(table.contains("Win Rate"), "Table should contain Win Rate header")
	gut.p(table)


func test_table_contains_all_values() -> void:
	var result := _make_mock_sweep_result()
	var table := result.table()
	assert_true(table.contains("30"), "Table should contain value 30")
	assert_true(table.contains("50"), "Table should contain value 50")
	assert_true(table.contains("75"), "Table should contain value 75")
	assert_true(table.contains("100"), "Table should contain value 100")


func test_find_threshold_interpolates() -> void:
	var result := _make_mock_sweep_result()
	# Win rates: 30→1.0, 50→0.8, 75→0.6, 100→0.3
	# 50% threshold is between 75 (0.6) and 100 (0.3)
	# Interpolation: 75 + (0.5 - 0.6) * (100 - 75) / (0.3 - 0.6) = 75 + (-0.1 * 25 / -0.3) = 75 + 8.33 = 83.33
	var threshold := result.find_threshold("player", 0.5)
	assert_almost_eq(threshold, 83.33, 1.0, "Threshold should be ~83.3")
	gut.p("50%% threshold: %.2f" % threshold)


func test_find_threshold_exact_match() -> void:
	var result := _make_mock_sweep_result()
	# Win rate at 50 is 0.8
	var threshold := result.find_threshold("player", 0.8)
	assert_almost_eq(threshold, 50.0, 1.0, "Exact match should return the param value")


func test_find_threshold_above_all() -> void:
	var result := _make_mock_sweep_result()
	# Target above all win rates — return first param value
	var threshold := result.find_threshold("player", 1.1)
	assert_eq(threshold, 30.0, "Above all should return first value")


func test_find_threshold_below_all() -> void:
	var result := _make_mock_sweep_result()
	# Target below all win rates — return last param value
	var threshold := result.find_threshold("player", 0.0)
	assert_eq(threshold, 100.0, "Below all should return last value")


func test_get_report_returns_correct_report() -> void:
	var result := _make_mock_sweep_result()
	var report := result.get_report(50.0)
	assert_not_null(report, "Should find report for value 50")
	assert_eq(report.runs.size(), 10, "Report should have 10 runs")
	assert_almost_eq(report.win_rate("player"), 0.8, 0.01, "Win rate at 50 should be 0.8")


func test_get_report_missing_value() -> void:
	var result := _make_mock_sweep_result()
	var report := result.get_report(999.0)
	assert_null(report, "Should return null for missing value")


func test_param_values() -> void:
	var result := _make_mock_sweep_result()
	var values := result.param_values()
	assert_eq(values.size(), 4)
	assert_eq(values[0], 30.0)
	assert_eq(values[1], 50.0)
	assert_eq(values[2], 75.0)
	assert_eq(values[3], 100.0)


func test_win_rates() -> void:
	var result := _make_mock_sweep_result()
	var rates := result.win_rates()
	assert_eq(rates.size(), 4)
	assert_almost_eq(rates[0], 1.0, 0.01)
	assert_almost_eq(rates[1], 0.8, 0.01)
	assert_almost_eq(rates[2], 0.6, 0.01)
	assert_almost_eq(rates[3], 0.3, 0.01)


func test_to_dict_structure() -> void:
	var result := _make_mock_sweep_result()
	var d := result.to_dict()
	assert_eq(d["param_name"], "enemy_hp")
	assert_eq(int(d["seed_used"]), 42)
	assert_eq(int(d["iterations_per_step"]), 10)
	assert_eq(d["steps"].size(), 4)
	var first_step: Dictionary = d["steps"][0]
	assert_true(first_step.has("value"), "Step should have value")
	assert_true(first_step.has("report"), "Step should have report")


func test_to_json_valid() -> void:
	var result := _make_mock_sweep_result()
	var json := result.to_json()
	assert_true(json.length() > 0, "JSON should be non-empty")
	var parsed = JSON.parse_string(json)
	assert_not_null(parsed, "JSON should be parseable")
	assert_eq(parsed["param_name"], "enemy_hp")


func test_save_writes_file() -> void:
	var result := _make_mock_sweep_result()
	var path := "user://test_sweep_report.json"
	var err := result.save(path)
	assert_eq(err, OK, "Save should succeed")
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "File should be readable")
	var parsed = JSON.parse_string(file.get_as_text())
	file = null
	assert_not_null(parsed, "Saved JSON should be parseable")
	assert_eq(parsed["steps"].size(), 4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# === T02: AutoSimSweepRunner tests ===

func test_sweep_runs_all_values() -> void:
	var adapter = CardBattleAdapter.new()
	var bot = AggressiveBot.new()
	var result := AutoSimSweepRunner.run(adapter, {"player": bot}, "enemy_hp", [30, 50, 100, 200])
	assert_eq(result.steps.size(), 4, "Should run all 4 values")
	var values := result.param_values()
	assert_eq(values[0], 30.0)
	assert_eq(values[1], 50.0)
	assert_eq(values[2], 100.0)
	assert_eq(values[3], 200.0)


func test_sweep_uses_same_seed() -> void:
	var adapter_a = CardBattleAdapter.new()
	var adapter_b = CardBattleAdapter.new()
	var bot_a = RandomBot.new()
	var bot_b = RandomBot.new()
	var result_a := AutoSimSweepRunner.run(adapter_a, {"player": bot_a}, "enemy_hp", [30, 100], 50, 42)
	var result_b := AutoSimSweepRunner.run(adapter_b, {"player": bot_b}, "enemy_hp", [30, 100], 50, 42)
	for i in result_a.steps.size():
		var report_a: AutoSimBalanceReport = result_a.steps[i]["report"]
		var report_b: AutoSimBalanceReport = result_b.steps[i]["report"]
		assert_eq(report_a.win_rate("player"), report_b.win_rate("player"),
			"Same seed should produce same win rate at step %d" % i)
		for j in report_a.runs.size():
			assert_eq(report_a.runs[j].turns, report_b.runs[j].turns,
				"Same seed should produce same turns at step %d run %d" % [i, j])


func test_sweep_sets_property() -> void:
	var adapter = CardBattleAdapter.new()
	var bot = AggressiveBot.new()
	var result := AutoSimSweepRunner.run(adapter, {"player": bot}, "enemy_hp", [30, 200], 100, 42)
	var report_easy: AutoSimBalanceReport = result.steps[0]["report"]
	var report_hard: AutoSimBalanceReport = result.steps[1]["report"]
	var wr_easy := report_easy.win_rate("player")
	var wr_hard := report_hard.win_rate("player")
	assert_gt(wr_easy, wr_hard, "Weak enemy should have higher win rate than strong")
	gut.p("Win rate at 30HP: %.1f%% | at 200HP: %.1f%%" % [wr_easy * 100, wr_hard * 100])


func test_sweep_default_iterations() -> void:
	var adapter = CardBattleAdapter.new()
	var bot = AggressiveBot.new()
	var result := AutoSimSweepRunner.run(adapter, {"player": bot}, "enemy_hp", [50])
	var report_default: AutoSimBalanceReport = result.steps[0]["report"]
	assert_eq(report_default.runs.size(), 200, "Default should be 200 iterations")
	assert_eq(result.iterations_per_step, 200)


func test_sweep_custom_iterations() -> void:
	var adapter = CardBattleAdapter.new()
	var bot = AggressiveBot.new()
	var result := AutoSimSweepRunner.run(adapter, {"player": bot}, "enemy_hp", [50], 50)
	var report_custom: AutoSimBalanceReport = result.steps[0]["report"]
	assert_eq(report_custom.runs.size(), 50, "Should respect custom iterations")
	assert_eq(result.iterations_per_step, 50)


func test_sweep_result_integration() -> void:
	var adapter = CardBattleAdapter.new()
	var bot = AggressiveBot.new()
	var result := AutoSimSweepRunner.run(adapter, {"player": bot}, "enemy_hp", [30, 75, 150, 300], 100, 42)
	var table := result.table()
	assert_true(table.length() > 0, "Table should be non-empty")
	gut.p(table)
	var threshold := result.find_threshold("player", 0.5)
	assert_between(threshold, 30.0, 300.0, "Threshold should be within param range")
	gut.p("50%% win rate threshold: %.1f enemy HP" % threshold)


func test_sweep_invalid_property() -> void:
	var adapter = CardBattleAdapter.new()
	var bot = AggressiveBot.new()
	var result := AutoSimSweepRunner.run(adapter, {"player": bot}, "nonexistent_prop", [30, 50])
	assert_eq(result.steps.size(), 0, "Invalid property should return empty result")


# === T03: CLI sweep parsing ===

func test_parse_sweep_arg() -> void:
	var parsed := _parse_sweep("enemy_hp:30,50,75,100")
	assert_eq(parsed["param"], "enemy_hp")
	assert_eq(parsed["values"].size(), 4)
	assert_eq(parsed["values"][0], 30.0)
	assert_eq(parsed["values"][3], 100.0)


func test_parse_sweep_arg_floats() -> void:
	var parsed := _parse_sweep("damage_mult:0.5,1.0,1.5,2.0")
	assert_eq(parsed["param"], "damage_mult")
	assert_almost_eq(parsed["values"][0], 0.5, 0.01)
	assert_almost_eq(parsed["values"][3], 2.0, 0.01)


func test_parse_sweep_arg_single_value() -> void:
	var parsed := _parse_sweep("hp:100")
	assert_eq(parsed["param"], "hp")
	assert_eq(parsed["values"].size(), 1)
	assert_eq(parsed["values"][0], 100.0)


# Mirrors cli.gd._parse_sweep — can't call it directly (no class_name on SceneTree script)
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
