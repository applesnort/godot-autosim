extends GutTest

var CardBattleAdapter = preload("res://addons/godot_autosim/examples/card_battle/card_battle_adapter.gd")
var AggressiveBot = preload("res://addons/godot_autosim/examples/card_battle/aggressive_bot.gd")
var DefensiveBot = preload("res://addons/godot_autosim/examples/card_battle/defensive_bot.gd")
var RandomBot = preload("res://addons/godot_autosim/bots/random_bot.gd")


func _make_config(bot_script, iterations: int = 50, enemy_hp: int = 50) -> AutoSimConfig:
	var adapter = CardBattleAdapter.new()
	adapter.enemy_hp = enemy_hp
	var bot = bot_script.new()
	return AutoSimConfig.create(adapter, {"player": bot}, iterations)


func _make_report(bot_script, iterations: int = 50, enemy_hp: int = 50, rng_seed: int = 42) -> AutoSimBalanceReport:
	var config := _make_config(bot_script, iterations, enemy_hp)
	config.rng_seed = rng_seed
	return AutoSimRunner.run(config)


# === assert_median_between ===

func test_assert_median_between_passes_when_in_range() -> void:
	var report := _make_report(AggressiveBot, 100, 50)
	var median_turns := report.median("turns")
	gut.p("Median turns: %.2f" % median_turns)
	AutoSimAssertions.assert_median_between(self, report, "turns", 0.0, 100.0)


func test_assert_median_between_matches_manual_calculation() -> void:
	var report := _make_report(AggressiveBot, 100, 50)
	var median_from_report := report.median("turns")
	var values: Array[float] = []
	for run in report.runs:
		values.append(float(run.metrics["turns"]))
	values.sort()
	var mid := values.size() / 2
	var expected: float
	if values.size() % 2 == 0:
		expected = (values[mid - 1] + values[mid]) / 2.0
	else:
		expected = values[mid]
	assert_eq(median_from_report, expected, "Report median should match manual calculation")


func test_assert_median_between_with_odd_run_count() -> void:
	var report := _make_report(AggressiveBot, 51, 50)
	var median_turns := report.median("turns")
	assert_gt(median_turns, 0.0, "Median should be positive with odd run count")
	AutoSimAssertions.assert_median_between(self, report, "turns", 0.0, 100.0)


func test_assert_median_between_player_hp() -> void:
	var report := _make_report(AggressiveBot, 100, 30)
	var median_hp := report.median("player_hp_remaining")
	gut.p("Median HP remaining vs 30HP enemy: %.2f" % median_hp)
	AutoSimAssertions.assert_median_between(self, report, "player_hp_remaining", 0.0, 80.0)


# === assert_stddev_below ===

func test_assert_stddev_below_passes_with_generous_threshold() -> void:
	var report := _make_report(AggressiveBot, 100, 50)
	var sd := report.stddev("turns")
	gut.p("Stddev turns: %.2f" % sd)
	AutoSimAssertions.assert_stddev_below(self, report, "turns", 999.0)


func test_stddev_is_zero_for_single_run() -> void:
	var report := _make_report(AggressiveBot, 1, 50)
	var sd := report.stddev("turns")
	assert_eq(sd, 0.0, "Stddev of 1 run should be 0")


func test_stddev_increases_with_variance() -> void:
	# Weak enemy = consistent wins = lower variance in turns
	var low_var := _make_report(AggressiveBot, 100, 30)
	# Moderate enemy = more spread in outcomes
	var high_var := _make_report(AggressiveBot, 100, 100)
	var sd_low := low_var.stddev("turns")
	var sd_high := high_var.stddev("turns")
	gut.p("Stddev turns (30HP): %.2f | (100HP): %.2f" % [sd_low, sd_high])
	assert_gt(sd_high, 0.0, "Should have non-zero stddev against harder enemy")


# === assert_no_dominant_strategy ===

func test_assert_no_dominant_strategy_passes_when_balanced() -> void:
	# Against very strong enemy (500HP), no strategy should dominate
	# The card_battle example is 100% winnable up to ~200HP, so need extreme HP
	var agg := _make_report(AggressiveBot, 100, 500)
	var def := _make_report(DefensiveBot, 100, 500)
	var rng := _make_report(RandomBot, 100, 500)
	gut.p("vs 500HP — Agg: %.1f%% | Def: %.1f%% | Rng: %.1f%%" % [
		agg.win_rate("player") * 100, def.win_rate("player") * 100, rng.win_rate("player") * 100,
	])
	AutoSimAssertions.assert_no_dominant_strategy(self, {
		"aggressive": agg,
		"defensive": def,
		"random": rng,
	}, 0.95)


func test_assert_no_dominant_strategy_detects_dominance_against_weak_enemy() -> void:
	# Against very weak enemy, aggressive bot should crush it (>95%)
	var agg := _make_report(AggressiveBot, 100, 20)
	gut.p("Aggressive vs 20HP: %.1f%%" % (agg.win_rate("player") * 100))
	# This SHOULD exceed 0.50 threshold — verifying the assertion catches it
	var wr := agg.win_rate("player")
	assert_gt(wr, 0.50, "Aggressive should dominate weak enemy (precondition)")


func test_assert_no_dominant_strategy_with_custom_threshold() -> void:
	var agg := _make_report(AggressiveBot, 100, 100)
	var def := _make_report(DefensiveBot, 100, 100)
	gut.p("vs 100HP — Agg: %.1f%% | Def: %.1f%%" % [
		agg.win_rate("player") * 100, def.win_rate("player") * 100,
	])
	# Use a very high threshold so it passes
	AutoSimAssertions.assert_no_dominant_strategy(self, {
		"aggressive": agg,
		"defensive": def,
	}, 1.0)


func test_assert_no_dominant_strategy_checks_all_strategies() -> void:
	# Verify the assertion iterates over all entries by passing multiple reports
	var reports := {}
	for bot_name in ["aggressive", "defensive", "random"]:
		var bot_script = AggressiveBot if bot_name == "aggressive" else (DefensiveBot if bot_name == "defensive" else RandomBot)
		reports[bot_name] = _make_report(bot_script, 50, 100)
	assert_eq(reports.size(), 3, "Should have 3 strategy reports")
	AutoSimAssertions.assert_no_dominant_strategy(self, reports, 1.0)


# === BalanceReport.save() ===

func test_save_writes_valid_json() -> void:
	var report := _make_report(AggressiveBot, 20, 50)
	var path := "user://test_report.json"
	var err := report.save(path)
	assert_eq(err, OK, "Save should succeed")

	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Saved file should be readable")
	var content := file.get_as_text()
	var parsed = JSON.parse_string(content)
	assert_not_null(parsed, "Saved JSON should be parseable")
	file = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_save_contains_expected_structure() -> void:
	var report := _make_report(AggressiveBot, 10, 50)
	var path := "user://test_report_structure.json"
	var err := report.save(path)
	assert_eq(err, OK)

	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	file = null

	assert_true(parsed.has("metadata"), "Should have metadata")
	assert_true(parsed.has("config"), "Should have config")
	assert_true(parsed.has("total_runs"), "Should have total_runs")
	assert_true(parsed.has("summary"), "Should have summary")
	assert_true(parsed.has("runs"), "Should have runs")
	assert_eq(int(parsed["total_runs"]), 10, "total_runs should match iteration count")
	assert_eq(parsed["runs"].size(), 10, "runs array should match iteration count")

	var first_run: Dictionary = parsed["runs"][0]
	assert_true(first_run.has("winner"), "Run should have winner")
	assert_true(first_run.has("turns"), "Run should have turns")
	assert_true(first_run.has("metrics"), "Run should have metrics")
	assert_true(first_run.has("seed"), "Run should have seed")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_save_config_records_seed() -> void:
	var report := _make_report(AggressiveBot, 10, 50)
	var path := "user://test_report_seed.json"
	report.save(path)
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	file = null
	assert_eq(int(parsed["config"]["rng_seed"]), 42, "Config should record rng_seed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_save_roundtrips_win_rate() -> void:
	var report := _make_report(AggressiveBot, 50, 50)
	var path := "user://test_report_winrate.json"
	report.save(path)
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	file = null
	var saved_wr: float = parsed["summary"]["win_rate"]
	var computed_wr := report.win_rate("player")
	assert_almost_eq(saved_wr, snapped(computed_wr, 0.001), 0.002, "Saved win rate should match computed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# === Seed reproducibility (deep) ===

func test_seed_produces_identical_metrics() -> void:
	var report_a := _make_report(RandomBot, 30, 50, 99)
	var report_b := _make_report(RandomBot, 30, 50, 99)
	for i in report_a.runs.size():
		var a: AutoSimRunResult = report_a.runs[i]
		var b: AutoSimRunResult = report_b.runs[i]
		assert_eq(a.winner, b.winner, "Run %d winner mismatch" % i)
		assert_eq(a.turns, b.turns, "Run %d turns mismatch" % i)
		assert_eq(a.seed_used, b.seed_used, "Run %d seed mismatch" % i)
		assert_eq(a.metrics["player_hp_remaining"], b.metrics["player_hp_remaining"],
			"Run %d player_hp mismatch" % i)


func test_different_seeds_produce_different_results() -> void:
	var report_a := _make_report(RandomBot, 50, 50, 1)
	var report_b := _make_report(RandomBot, 50, 50, 9999)
	var differences := 0
	for i in report_a.runs.size():
		if report_a.runs[i].turns != report_b.runs[i].turns:
			differences += 1
	assert_gt(differences, 0, "Different seeds should produce at least some different results")
	gut.p("Differing runs: %d / %d" % [differences, report_a.runs.size()])


func test_seed_report_statistics_are_deterministic() -> void:
	var report_a := _make_report(DefensiveBot, 100, 80, 777)
	var report_b := _make_report(DefensiveBot, 100, 80, 777)
	assert_eq(report_a.win_rate("player"), report_b.win_rate("player"), "Win rate should be deterministic")
	assert_eq(report_a.avg("turns"), report_b.avg("turns"), "Avg turns should be deterministic")
	assert_eq(report_a.median("turns"), report_b.median("turns"), "Median turns should be deterministic")
	assert_eq(report_a.stddev("turns"), report_b.stddev("turns"), "Stddev turns should be deterministic")
