# PRD: Parameter Sweep Runner

## Status: Approved

## Problem Statement

Users have to manually re-run simulations with different config values to find the right balance point, then eyeball when a metric crosses their target. If you want to know "at what enemy HP does win rate drop below 50%?", you currently run the simulation 5-10 times with different HP values, compare the numbers, and guess.

This affects every godot-autosim user who is tuning balance — which is the primary use case.

## Goals

- User specifies a parameter, a range of values, and gets back a data structure showing how win rate and metrics change across that range.
- User can find the threshold value where a metric crosses a target (e.g., "win rate crosses 50% at enemy_hp ≈ 83").
- Works from code and from CLI with zero additional dependencies.

## Anti-Goals

- No visualization (separate roadmap item — the sweep produces data, visualization renders it).
- No multi-parameter sweeps (varying two things at once). Single parameter only.
- No automatic "recommend the best value." Just data.

## Solution Overview

New `AutoSimSweepRunner` class with a single static `run()` method. The user passes their adapter, bot strategies, the name of the property to vary (as a string), and an array of values to try. The runner sets the property on the adapter via `adapter.set()`, runs a full simulation batch for each value, and returns an `AutoSimSweepResult`.

The sweep result provides a formatted table, threshold finding via linear interpolation, per-value report access, and JSON export.

Same seed is used across all sweep steps so the only variable is the parameter being changed.

### API

```gdscript
var result = AutoSimSweepRunner.run(
    MyAdapter.new(),
    {"player": AggressiveBot.new()},
    "enemy_hp",
    [30, 50, 75, 100, 150, 200]
)

print(result.table())
print(result.find_threshold("player", 0.5))  # → 83.0
result.save("sweep_report.json")
```

### CLI

```bash
godot --headless --script addons/godot_autosim/cli/cli.gd -- \
  --adapter=res://my_adapter.gd \
  --strategy=res://bot.gd \
  --sweep=enemy_hp:30,50,75,100,150,200 \
  --output=sweep_report.json
```

## Technical Approach

### Data Model

**AutoSimSweepResult** — new class in `addons/godot_autosim/core/sweep_result.gd`

Properties:
- `param_name: String` — name of the swept parameter
- `steps: Array[Dictionary]` — each entry: `{value: float, report: AutoSimBalanceReport}`
- `seed_used: int` — the seed used across all steps
- `iterations_per_step: int` — how many runs per parameter value

Methods:
- `table(role: String = "player") -> String` — formatted table with win rate + all metrics
- `find_threshold(role: String, target_win_rate: float) -> float` — linear interpolation
- `get_report(param_value: float) -> AutoSimBalanceReport` — full report for one step
- `param_values() -> Array[float]` — list of all tested values
- `win_rates(role: String = "player") -> Array[float]` — win rate per step
- `to_dict() -> Dictionary` — serializable structure
- `to_json() -> String` — JSON string
- `save(path: String) -> Error` — write JSON to file

**AutoSimSweepRunner** — new class in `addons/godot_autosim/core/sweep_runner.gd`

Static methods:
- `run(adapter, strategies, param_name, values, iterations, rng_seed) -> AutoSimSweepResult`

### Patterns & Reuse

- Reuses `AutoSimRunner.run()` internally for each step — no duplication of the game loop.
- Reuses `AutoSimBalanceReport` for per-step data.
- `table()` formatting follows the pattern of `BalanceReport.summary()`.
- `save()`/`to_json()`/`to_dict()` follow existing BalanceReport patterns.
- CLI changes extend existing argument parsing in `cli.gd`.

### Performance

Each sweep step runs a full simulation batch. With 10 values × 200 iterations, that's 2000 total runs. The card battle adapter does ~1000 runs/second, so a full sweep completes in ~2 seconds. Acceptable.

## Atomic Task Table (TDD order)

| ID | Phase | Task | Type | Agent | Deps | Est |
|----|-------|------|------|-------|------|-----|
| T01 | 0 | Write failing tests for AutoSimSweepResult | test | haiku | [] | S |
| M01 | 0 | Implement AutoSimSweepResult | model | sonnet | [T01] | M |
| T02 | 1 | Write failing tests for AutoSimSweepRunner | test | haiku | [] | S |
| S01 | 1 | Implement AutoSimSweepRunner | service | sonnet | [T02, M01] | M |
| T03 | 2 | Write failing tests for CLI sweep mode | test | haiku | [] | S |
| W01 | 2 | Add --sweep flag to CLI | wiring | sonnet | [T03, S01] | S |
| D01 | 3 | Update README with sweep documentation | docs | haiku | [W01] | S |

## Verification

- [ ] All T## test tasks written before implementation
- [ ] All tests passing after implementation (39 existing + new sweep tests)
- [ ] CLI sweep produces correct table output
- [ ] find_threshold returns interpolated value matching manual calculation
- [ ] Same seed across steps produces deterministic results
- [ ] JSON export contains all sweep data
- [ ] README documents sweep API and CLI usage

## Priority & Timeline

Must-have for v0.3. No external dependencies. Can be completed in one session.
