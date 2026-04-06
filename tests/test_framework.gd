extends GutTest

var CardBattleAdapter = preload("res://examples/card_battle/card_battle_adapter.gd")
var AggressiveBot = preload("res://examples/card_battle/aggressive_bot.gd")
var DefensiveBot = preload("res://examples/card_battle/defensive_bot.gd")
var RandomBot = preload("res://examples/card_battle/random_bot.gd")


func _make_config(bot_script, iterations: int = 50, enemy_hp: int = 50) -> AutoSimConfig:
	var adapter = CardBattleAdapter.new()
	adapter.enemy_hp = enemy_hp
	var bot = bot_script.new()
	return AutoSimConfig.create(adapter, {"player": bot}, iterations)


# === SimRunner basics ===

func test_runner_completes_all_iterations() -> void:
	var config := _make_config(AggressiveBot, 20)
	var report := AutoSimRunner.run(config)
	assert_eq(report.runs.size(), 20)


func test_runner_records_winners() -> void:
	var config := _make_config(AggressiveBot, 50)
	var report := AutoSimRunner.run(config)
	var wins := report.win_count("player")
	var losses := report.loss_count("player")
	assert_eq(wins + losses, 50, "Every run should have a winner or loser")


func test_runner_records_turns() -> void:
	var config := _make_config(AggressiveBot, 10)
	var report := AutoSimRunner.run(config)
	for run in report.runs:
		assert_gt(run.turns, 0, "Every run should take at least 1 turn")


func test_runner_records_metrics() -> void:
	var config := _make_config(AggressiveBot, 10)
	var report := AutoSimRunner.run(config)
	for run in report.runs:
		assert_true(run.metrics.has("player_hp_remaining"))
		assert_true(run.metrics.has("enemy_hp_remaining"))
		assert_true(run.metrics.has("turns"))


func test_runner_respects_max_turns() -> void:
	# Enemy with 99999 HP should timeout
	var config := _make_config(AggressiveBot, 5, 99999)
	config.max_turns = 50
	var report := AutoSimRunner.run(config)
	for run in report.runs:
		assert_lte(run.turns, 50, "Should not exceed max_turns")


func test_reproducible_with_seed() -> void:
	var config1 := _make_config(RandomBot, 20)
	config1.rng_seed = 42
	var report1 := AutoSimRunner.run(config1)

	var config2 := _make_config(RandomBot, 20)
	config2.rng_seed = 42
	var report2 := AutoSimRunner.run(config2)

	for i in report1.runs.size():
		assert_eq(report1.runs[i].winner, report2.runs[i].winner,
			"Same seed should produce same results (run %d)" % i)
		assert_eq(report1.runs[i].turns, report2.runs[i].turns,
			"Same seed should produce same turn count (run %d)" % i)


# === BalanceReport statistics ===

func test_win_rate_calculation() -> void:
	var config := _make_config(AggressiveBot, 100)
	var report := AutoSimRunner.run(config)
	var wr := report.win_rate("player")
	assert_between(wr, 0.0, 1.0, "Win rate should be between 0 and 1")


func test_avg_metric() -> void:
	var config := _make_config(AggressiveBot, 50)
	var report := AutoSimRunner.run(config)
	var avg_turns := report.avg("turns")
	assert_gt(avg_turns, 0.0, "Average turns should be positive")


func test_median_metric() -> void:
	var config := _make_config(AggressiveBot, 50)
	var report := AutoSimRunner.run(config)
	var median_turns := report.median("turns")
	assert_gt(median_turns, 0.0, "Median turns should be positive")


func test_stddev_metric() -> void:
	var config := _make_config(AggressiveBot, 50)
	var report := AutoSimRunner.run(config)
	var sd := report.stddev("turns")
	assert_gte(sd, 0.0, "Stddev should be non-negative")


func test_distribution() -> void:
	var config := _make_config(AggressiveBot, 100)
	var report := AutoSimRunner.run(config)
	var dist := report.distribution("turns", 5)
	assert_gt(dist.size(), 0, "Distribution should have buckets")
	var total := 0
	for bucket in dist:
		total += bucket["count"]
	assert_eq(total, 100, "Distribution should account for all runs")


func test_json_serialization() -> void:
	var config := _make_config(AggressiveBot, 10)
	var report := AutoSimRunner.run(config)
	var json := report.to_json()
	assert_true(json.length() > 0, "JSON should be non-empty")
	var parsed = JSON.parse_string(json)
	assert_not_null(parsed, "JSON should be valid")
	assert_eq(parsed["total_runs"], 10)


# === Strategy comparison ===

func test_aggressive_vs_weak_enemy_high_win_rate() -> void:
	var config := _make_config(AggressiveBot, 100, 30)
	var report := AutoSimRunner.run(config)
	gut.p("Aggressive vs 30HP: %s" % report.summary())
	assert_gte(report.win_rate("player"), 0.90, "Should easily beat weak enemy")


func test_aggressive_vs_strong_enemy_lower_win_rate() -> void:
	var config := _make_config(AggressiveBot, 100, 250)
	var report := AutoSimRunner.run(config)
	gut.p("Aggressive vs 250HP: %s" % report.summary())
	assert_lte(report.win_rate("player"), 0.90, "Should struggle against strong enemy")


func test_strategy_comparison() -> void:
	var aggressive_config := _make_config(AggressiveBot, 100, 50)
	var defensive_config := _make_config(DefensiveBot, 100, 50)
	var random_config := _make_config(RandomBot, 100, 50)

	var agg_report := AutoSimRunner.run(aggressive_config)
	var def_report := AutoSimRunner.run(defensive_config)
	var rng_report := AutoSimRunner.run(random_config)

	gut.p("Aggressive: %s" % agg_report.summary())
	gut.p("Defensive:  %s" % def_report.summary())
	gut.p("Random:     %s" % rng_report.summary())

	pass_test("Strategy comparison completed")
