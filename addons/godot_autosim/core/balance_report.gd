## Aggregated results from a simulation batch.
##
## Provides statistical accessors (win rate, averages, distributions)
## and serializes to JSON for external analysis.
class_name AutoSimBalanceReport
extends RefCounted

var runs: Array[AutoSimRunResult] = []
var metadata: Dictionary = {}
var config_summary: Dictionary = {}


func win_rate(role: String = "player") -> float:
	if runs.is_empty():
		return 0.0
	var wins := 0
	for run in runs:
		if run.winner == role:
			wins += 1
	return float(wins) / float(runs.size())


func win_count(role: String = "player") -> int:
	var wins := 0
	for run in runs:
		if run.winner == role:
			wins += 1
	return wins


func loss_count(role: String = "player") -> int:
	return runs.size() - win_count(role)


func avg(metric: String) -> float:
	if runs.is_empty():
		return 0.0
	var total := 0.0
	var count := 0
	for run in runs:
		if run.metrics.has(metric):
			total += float(run.metrics[metric])
			count += 1
	return total / float(maxi(count, 1))


func median(metric: String) -> float:
	var values: Array[float] = []
	for run in runs:
		if run.metrics.has(metric):
			values.append(float(run.metrics[metric]))
	if values.is_empty():
		return 0.0
	values.sort()
	var mid := values.size() / 2
	if values.size() % 2 == 0:
		return (values[mid - 1] + values[mid]) / 2.0
	return values[mid]


func stddev(metric: String) -> float:
	var values: Array[float] = []
	for run in runs:
		if run.metrics.has(metric):
			values.append(float(run.metrics[metric]))
	if values.size() < 2:
		return 0.0
	var mean := avg(metric)
	var sum_sq := 0.0
	for v in values:
		sum_sq += (v - mean) * (v - mean)
	return sqrt(sum_sq / float(values.size()))


func percentile(metric: String, p: float) -> float:
	var values: Array[float] = []
	for run in runs:
		if run.metrics.has(metric):
			values.append(float(run.metrics[metric]))
	if values.is_empty():
		return 0.0
	values.sort()
	var idx := int(floor(p / 100.0 * float(values.size() - 1)))
	return values[clampi(idx, 0, values.size() - 1)]


func min_value(metric: String) -> float:
	return percentile(metric, 0)


func max_value(metric: String) -> float:
	return percentile(metric, 100)


func distribution(metric: String, buckets: int = 10) -> Array[Dictionary]:
	var values: Array[float] = []
	for run in runs:
		if run.metrics.has(metric):
			values.append(float(run.metrics[metric]))
	if values.is_empty():
		return []
	values.sort()
	var lo := values[0]
	var hi := values[values.size() - 1]
	if lo == hi:
		return [{"min": lo, "max": hi, "count": values.size()}]
	var bucket_width := (hi - lo) / float(buckets)
	var result: Array[Dictionary] = []
	for i in buckets:
		var b_min := lo + i * bucket_width
		var b_max := b_min + bucket_width
		var count := 0
		for v in values:
			if v >= b_min and (v < b_max or (i == buckets - 1 and v <= b_max)):
				count += 1
		result.append({"min": snapped(b_min, 0.01), "max": snapped(b_max, 0.01), "count": count})
	return result


func summary(role: String = "player") -> String:
	var wr := win_rate(role)
	var avg_turns := avg("turns")
	return "%d runs | %.1f%% win rate | avg %.1f turns" % [
		runs.size(), wr * 100.0, avg_turns,
	]


func to_dict() -> Dictionary:
	var run_dicts: Array[Dictionary] = []
	for run in runs:
		run_dicts.append(run.to_dict())
	return {
		"metadata": metadata,
		"config": config_summary,
		"total_runs": runs.size(),
		"summary": {
			"win_rate": snapped(win_rate(), 0.001),
			"avg_turns": snapped(avg("turns"), 0.1),
		},
		"runs": run_dicts,
	}


func to_json() -> String:
	return JSON.stringify(to_dict(), "  ")


func save(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_json())
	return OK
