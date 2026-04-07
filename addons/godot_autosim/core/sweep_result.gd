## Results from a parameter sweep — one BalanceReport per parameter value.
##
## Provides table formatting, threshold finding via linear interpolation,
## and JSON export.
class_name AutoSimSweepResult
extends RefCounted

var param_name: String = ""
var steps: Array[Dictionary] = []  # [{value: float, report: AutoSimBalanceReport}]
var seed_used: int = 0
var iterations_per_step: int = 0


func table(role: String = "player") -> String:
	if steps.is_empty():
		return ""

	var metric_keys: Array[String] = []
	for step in steps:
		var report: AutoSimBalanceReport = step["report"]
		for run in report.runs:
			for key in run.metrics:
				if key != "turns" and not metric_keys.has(key):
					metric_keys.append(key)

	var headers: Array[String] = [param_name, "Win Rate", "Avg Turns"]
	for key in metric_keys:
		headers.append("Avg %s" % key)

	var rows: Array[Array] = []
	for step in steps:
		var val: float = step["value"]
		var report: AutoSimBalanceReport = step["report"]
		var row: Array[String] = [
			str(snapped(val, 0.01)),
			"%.1f%%" % (report.win_rate(role) * 100.0),
			"%.1f" % report.avg("turns"),
		]
		for key in metric_keys:
			row.append("%.1f" % report.avg(key))
		rows.append(row)

	var col_widths: Array[int] = []
	for i in headers.size():
		var w: int = headers[i].length()
		for row in rows:
			w = maxi(w, row[i].length())
		col_widths.append(w)

	var lines: Array[String] = []

	var header_line := ""
	var separator := ""
	for i in headers.size():
		if i > 0:
			header_line += " | "
			separator += "-+-"
		header_line += headers[i].rpad(col_widths[i])
		separator += "-".repeat(col_widths[i])
	lines.append(header_line)
	lines.append(separator)

	for row in rows:
		var line := ""
		for i in row.size():
			if i > 0:
				line += " | "
			if i == 0:
				line += row[i].rpad(col_widths[i])
			else:
				line += row[i].lpad(col_widths[i])
		lines.append(line)

	return "\n".join(lines)


func find_threshold(role: String, target_win_rate: float) -> float:
	if steps.is_empty():
		return 0.0

	var rates := win_rates(role)
	var values := param_values()

	for i in rates.size():
		if is_equal_approx(rates[i], target_win_rate):
			return values[i]

	for i in range(rates.size() - 1):
		var r1: float = rates[i]
		var r2: float = rates[i + 1]
		var crosses_down: bool = r1 > target_win_rate and r2 < target_win_rate
		var crosses_up: bool = r1 < target_win_rate and r2 > target_win_rate
		if crosses_down or crosses_up:
			var v1: float = values[i]
			var v2: float = values[i + 1]
			return v1 + (target_win_rate - r1) * (v2 - v1) / (r2 - r1)

	if target_win_rate >= rates[0]:
		return values[0]
	return values[values.size() - 1]


func get_report(param_value: float) -> AutoSimBalanceReport:
	for step in steps:
		if is_equal_approx(float(step["value"]), param_value):
			return step["report"]
	return null


func param_values() -> Array[float]:
	var values: Array[float] = []
	for step in steps:
		values.append(float(step["value"]))
	return values


func win_rates(role: String = "player") -> Array[float]:
	var rates: Array[float] = []
	for step in steps:
		var report: AutoSimBalanceReport = step["report"]
		rates.append(report.win_rate(role))
	return rates


func to_dict() -> Dictionary:
	var step_dicts: Array[Dictionary] = []
	for step in steps:
		var report: AutoSimBalanceReport = step["report"]
		step_dicts.append({
			"value": step["value"],
			"report": report.to_dict(),
		})
	return {
		"param_name": param_name,
		"seed_used": seed_used,
		"iterations_per_step": iterations_per_step,
		"steps": step_dicts,
	}


func to_json() -> String:
	return JSON.stringify(to_dict(), "  ")


func save(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_json())
	return OK
