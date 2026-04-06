## Statistical assertion helpers for use in GUT balance tests.
##
## Usage in a GUT test:
##   var report := AutoSimRunner.run(config)
##   AutoSimAssertions.assert_win_rate_between(self, report, "player", 0.4, 0.6)
class_name AutoSimAssertions
extends RefCounted


static func assert_win_rate_between(
	test: Node,  # GutTest instance
	report: AutoSimBalanceReport,
	role: String,
	low: float,
	high: float,
	msg: String = "",
) -> void:
	var wr := report.win_rate(role)
	var text := msg if msg != "" else "Win rate for '%s' (%.1f%%) should be between %.1f%% and %.1f%%" % [
		role, wr * 100.0, low * 100.0, high * 100.0,
	]
	test.assert_between(wr, low, high, text)


static func assert_avg_between(
	test: Node,
	report: AutoSimBalanceReport,
	metric: String,
	low: float,
	high: float,
	msg: String = "",
) -> void:
	var val := report.avg(metric)
	var text := msg if msg != "" else "Avg '%s' (%.2f) should be between %.2f and %.2f" % [
		metric, val, low, high,
	]
	test.assert_between(val, low, high, text)


static func assert_median_between(
	test: Node,
	report: AutoSimBalanceReport,
	metric: String,
	low: float,
	high: float,
	msg: String = "",
) -> void:
	var val := report.median(metric)
	var text := msg if msg != "" else "Median '%s' (%.2f) should be between %.2f and %.2f" % [
		metric, val, low, high,
	]
	test.assert_between(val, low, high, text)


static func assert_stddev_below(
	test: Node,
	report: AutoSimBalanceReport,
	metric: String,
	max_stddev: float,
	msg: String = "",
) -> void:
	var val := report.stddev(metric)
	var text := msg if msg != "" else "Stddev of '%s' (%.2f) should be below %.2f" % [
		metric, val, max_stddev,
	]
	test.assert_lte(val, max_stddev, text)


static func assert_no_dominant_strategy(
	test: Node,
	reports: Dictionary,  # strategy_name -> AutoSimBalanceReport
	max_win_rate: float = 0.95,
	role: String = "player",
	msg: String = "",
) -> void:
	for strategy_name in reports:
		var report: AutoSimBalanceReport = reports[strategy_name]
		var wr := report.win_rate(role)
		var text := msg if msg != "" else "Strategy '%s' win rate %.1f%% should not exceed %.1f%%" % [
			strategy_name, wr * 100.0, max_win_rate * 100.0,
		]
		test.assert_lte(wr, max_win_rate, text)
