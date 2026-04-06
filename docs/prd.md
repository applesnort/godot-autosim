# GodotBalanceTester -- Product Requirements Document

**Version:** 0.1 (MVP)
**Author:** Joel
**Date:** 2026-04-05
**Status:** Draft

---

## 1. Problem Statement

Game balance is the hardest thing to get right by hand. Roguelikes, card games, and strategy games have exponential interaction spaces -- a single stat tweak ripples through every encounter. The standard indie workflow is: playtest manually, guess, tweak, repeat. This is slow, biased (the designer knows the optimal strategy), and doesn't scale.

Unity solved this years ago with ML-Agents: spin up thousands of headless game instances, let bots play, collect stats, tune parameters from data instead of gut feel. **Godot has nothing equivalent.**

What exists today:

| Tool | What it does | What it doesn't do |
|------|-------------|-------------------|
| **GUT** (Godot Unit Testing) | Unit/integration tests for GDScript | Batch simulation, statistical assertions, balance reports |
| **WAT** | Alternative test framework | Same gap as GUT |
| **Manual playtesting** | Human plays the game | Doesn't scale, introduces bias, can't run 10,000 games overnight |

The gap: there is no framework that lets a Godot developer define bot strategies, run thousands of headless game simulations, collect metrics, and make statistical assertions about game balance -- all from the command line, integrated into CI.

GodotBalanceTester fills that gap.

---

## 2. Target Users

**Primary:** Indie developers building games with discrete, simulatable game loops in Godot 4.6+.

- **Card game developers** -- need win rate parity across factions/decks, mana curve validation, first-player advantage measurement
- **Roguelike developers** -- need run completion rates, item/build viability distributions, difficulty curve validation
- **Turn-based strategy developers** -- need faction balance, map advantage analysis, unit cost-effectiveness curves
- **Auto-battler / idle game developers** -- need progression rate validation, stat growth curves

**Secondary:**
- **Game design students** exploring balance through simulation
- **Jam developers** who want quick balance sanity checks
- **QA teams** at small studios adding balance regression tests to CI

**Non-users:**
- Developers of real-time physics-heavy games where headless simulation isn't meaningful (FPS, racing). These games need different testing approaches.

---

## 3. Design Principles

1. **Zero coupling to any specific game.** The framework provides the runner, the interfaces, and the reporting. The user provides the game logic and the bot strategies.
2. **GDScript-native.** No C#, no external binaries, no Python bridges. Everything is GDScript so it works in any Godot project without engine recompilation.
3. **Headless-first.** Designed to run with `--headless`. No scene tree dependencies unless the user's game requires them.
4. **Composable with GUT.** Balance tests should live alongside unit tests. Statistical assertions should feel like regular test assertions.
5. **Data out, opinions out.** The framework collects whatever metrics the user defines and outputs structured JSON. It does not prescribe what "balanced" means.

---

## 4. Architecture

```
+------------------+       +------------------+       +------------------+
|   CLI Runner     | ----> |   SimRunner      | ----> |  BalanceReport   |
|  (cli.gd)       |       |                  |       |  (JSON output)   |
+------------------+       +------------------+       +------------------+
                                  |
                                  | runs N iterations of
                                  v
                           +------------------+
                           | GameAdapter      |
                           | (user implements)|
                           +------------------+
                                  |
                                  | bots interact via
                                  v
                           +------------------+
                           | BotStrategy      |
                           | (user implements)|
                           +------------------+
```

### 4.1 Core Components

#### SimRunner

The orchestrator. Takes a `GameAdapter`, one or more `BotStrategy` instances, and a run configuration. Executes N game simulations sequentially (v0.1) or in parallel (future), collecting `RunResult` data from each.

**Responsibilities:**
- Initialize game state via `GameAdapter` for each run
- Assign `BotStrategy` instances to players/roles
- Step through the game loop until the game reports completion
- Collect `RunResult` from each completed run
- Aggregate results into a `BalanceReport`
- Handle timeouts (max turns/steps per run)
- Seed RNG for reproducibility

#### GameAdapter (user implements)

The bridge between the framework and the user's game. This is an abstract class the user extends to expose their game's state and actions to the framework.

**Responsibilities:**
- Create a fresh game state for each run
- Expose available actions to bots
- Apply bot-chosen actions to game state
- Report whether the game is over and who won
- Emit per-run metrics the user cares about

#### BotStrategy (user implements)

A decision-making agent that chooses actions given game state. Users implement different strategies to simulate different player skill levels or playstyles.

**Responsibilities:**
- Receive game state (read-only view)
- Receive available actions
- Return chosen action
- Optionally maintain internal state across turns within a single game

#### BalanceReport

A data container that aggregates metrics across all runs and serializes to JSON.

**Responsibilities:**
- Accumulate per-run results
- Compute summary statistics (mean, median, stddev, percentiles)
- Serialize to JSON
- Provide accessor methods for use in assertions

#### Statistical Assertions

A library of assertion functions that wrap `BalanceReport` data and produce clear pass/fail messages. Designed to be called from GUT tests.

---

## 5. API Surface

### 5.1 What the framework provides

```gdscript
# ---- Core classes ----

class_name SimRunner extends RefCounted

func configure(config: SimConfig) -> SimRunner
func run() -> BalanceReport


class_name SimConfig extends RefCounted

var iterations: int = 100
var game_adapter: GameAdapter
var strategies: Dictionary  # role_name -> BotStrategy
var rng_seed: int = -1      # -1 = random seed per run
var max_turns: int = 1000   # safety valve
var metadata: Dictionary = {}


class_name BalanceReport extends RefCounted

var runs: Array[RunResult]
var metadata: Dictionary

func win_rate(role: String) -> float
func win_count(role: String) -> int
func avg(metric: String) -> float
func median(metric: String) -> float
func stddev(metric: String) -> float
func percentile(metric: String, p: float) -> float
func distribution(metric: String, bucket_count: int) -> Array[Dictionary]
func to_json() -> String
func save(path: String) -> Error


class_name RunResult extends RefCounted

var winner: String          # role name or "" for draw
var turns: int
var metrics: Dictionary     # user-defined key -> float
var seed: int               # RNG seed used for this run


# ---- Assertion helpers (for use in GUT tests) ----

class_name BalanceAssertions extends RefCounted

static func assert_win_rate_between(report: BalanceReport, role: String, low: float, high: float) -> void
static func assert_avg_between(report: BalanceReport, metric: String, low: float, high: float) -> void
static func assert_median_between(report: BalanceReport, metric: String, low: float, high: float) -> void
static func assert_stddev_below(report: BalanceReport, metric: String, max_stddev: float) -> void
static func assert_no_dominant_strategy(report: BalanceReport, max_win_rate: float) -> void
```

### 5.2 What the user implements

```gdscript
# ---- GameAdapter (abstract) ----

class_name GameAdapter extends RefCounted

# Called once per run. Return a fresh game state object.
# The framework treats this as opaque -- only BotStrategy and your
# adapter need to understand it.
func create_initial_state() -> Variant:
    push_error("GameAdapter.create_initial_state() not implemented")
    return null

# Return the list of role names (e.g., ["player_1", "player_2"]).
func get_roles() -> Array[String]:
    push_error("GameAdapter.get_roles() not implemented")
    return []

# Return whose turn it is (role name).
func get_current_role(state: Variant) -> String:
    push_error("GameAdapter.get_current_role() not implemented")
    return ""

# Return available actions for the current role.
# Actions are Variant -- the framework doesn't interpret them.
func get_available_actions(state: Variant) -> Array:
    push_error("GameAdapter.get_available_actions() not implemented")
    return []

# Apply an action to the state. Return the mutated state.
func apply_action(state: Variant, action: Variant) -> Variant:
    push_error("GameAdapter.apply_action() not implemented")
    return state

# Return true when the game is over.
func is_game_over(state: Variant) -> bool:
    push_error("GameAdapter.is_game_over() not implemented")
    return true

# Return the winning role name, or "" for a draw.
func get_winner(state: Variant) -> String:
    push_error("GameAdapter.get_winner() not implemented")
    return ""

# Return any metrics you want tracked for this run.
# Called once when the game ends.
func get_run_metrics(state: Variant) -> Dictionary:
    return {}


# ---- BotStrategy (abstract) ----

class_name BotStrategy extends RefCounted

# Called at the start of each new game run.
func reset() -> void:
    pass

# Given game state and available actions, return the chosen action.
func choose_action(state: Variant, available_actions: Array) -> Variant:
    push_error("BotStrategy.choose_action() not implemented")
    return null
```

### 5.3 Built-in strategies (framework provides)

```gdscript
# Picks a random action each turn. Useful as a baseline.
class_name RandomStrategy extends BotStrategy

func choose_action(state: Variant, available_actions: Array) -> Variant:
    return available_actions[randi() % available_actions.size()]


# Always picks the first available action. Useful for testing
# deterministic paths.
class_name FirstActionStrategy extends BotStrategy

func choose_action(state: Variant, available_actions: Array) -> Variant:
    return available_actions[0]
```

---

## 6. Integration with GUT

Balance tests are GUT test scripts that construct a `SimRunner`, run simulations, and make statistical assertions on the report. They live in the same `test/` directory as other tests but are typically tagged or placed in a subdirectory so they can be run separately (they're slower).

### 6.1 Pattern

```gdscript
# test/balance/test_faction_balance.gd
extends GutTest

var _adapter: MyCardGameAdapter
var _report: BalanceReport

func before_all():
    _adapter = MyCardGameAdapter.new()

    var config = SimConfig.new()
    config.iterations = 500
    config.game_adapter = _adapter
    config.strategies = {
        "player_1": AggressiveStrategy.new(),
        "player_2": AggressiveStrategy.new(),
    }
    config.max_turns = 200

    var runner = SimRunner.new().configure(config)
    _report = runner.run()

func test_no_first_player_advantage():
    BalanceAssertions.assert_win_rate_between(_report, "player_1", 0.45, 0.55)

func test_games_end_in_reasonable_turns():
    BalanceAssertions.assert_avg_between(_report, "turns", 5.0, 30.0)
    BalanceAssertions.assert_stddev_below(_report, "turns", 10.0)

func test_damage_output_is_bounded():
    BalanceAssertions.assert_avg_between(_report, "total_damage_dealt", 20.0, 80.0)
```

### 6.2 Running balance tests separately

```bash
# Run only balance tests (GUT tag filter)
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/balance/

# Run all tests (unit + balance)
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/
```

---

## 7. CLI Runner

For quick iteration without writing a GUT test, the CLI runner lets you execute simulations directly and dump a JSON report.

### 7.1 Usage

```bash
godot --headless --script addons/balance_tester/cli.gd -- \
    --adapter=res://game/adapters/card_game_adapter.gd \
    --strategies=player_1:res://game/strategies/aggressive.gd,player_2:res://game/strategies/defensive.gd \
    --iterations=1000 \
    --max-turns=200 \
    --seed=42 \
    --report=balance_report.json
```

### 7.2 Output

```json
{
    "metadata": {
        "iterations": 1000,
        "seed": 42,
        "adapter": "res://game/adapters/card_game_adapter.gd",
        "strategies": {
            "player_1": "res://game/strategies/aggressive.gd",
            "player_2": "res://game/strategies/defensive.gd"
        },
        "timestamp": "2026-04-05T14:30:00Z",
        "godot_version": "4.6.0",
        "duration_ms": 12340
    },
    "summary": {
        "win_rates": {
            "player_1": 0.62,
            "player_2": 0.35,
            "draw": 0.03
        },
        "metrics": {
            "turns": {
                "mean": 12.4,
                "median": 11.0,
                "stddev": 4.2,
                "min": 3,
                "max": 47,
                "p25": 9.0,
                "p75": 15.0,
                "p95": 22.0
            },
            "total_damage_dealt": {
                "mean": 45.2,
                "median": 43.0,
                "stddev": 12.1,
                "min": 8,
                "max": 112,
                "p25": 37.0,
                "p75": 52.0,
                "p95": 68.0
            }
        }
    },
    "runs": [
        {
            "winner": "player_1",
            "turns": 14,
            "seed": 42,
            "metrics": {
                "total_damage_dealt": 52.0
            }
        }
    ]
}
```

The `runs` array in the output is optional and gated behind a `--include-runs` flag to keep file sizes reasonable for large iteration counts.

---

## 8. Full Example: Hypothetical Card Game

### 8.1 Game adapter

```gdscript
# game/adapters/card_game_adapter.gd
class_name CardGameAdapter extends GameAdapter

func create_initial_state() -> Variant:
    var state = {
        "players": {
            "player_1": {"hp": 30, "mana": 1, "hand": [], "deck": [], "damage_dealt": 0},
            "player_2": {"hp": 30, "mana": 1, "hand": [], "deck": [], "damage_dealt": 0},
        },
        "current_role": "player_1",
        "turn": 0,
    }
    _build_deck(state, "player_1")
    _build_deck(state, "player_2")
    _draw_cards(state, "player_1", 3)
    _draw_cards(state, "player_2", 3)
    return state

func get_roles() -> Array[String]:
    return ["player_1", "player_2"]

func get_current_role(state: Variant) -> String:
    return state["current_role"]

func get_available_actions(state: Variant) -> Array:
    var role = state["current_role"]
    var player = state["players"][role]
    var actions: Array = []

    for card in player["hand"]:
        if card["cost"] <= player["mana"]:
            actions.append({"type": "play_card", "card": card})

    actions.append({"type": "end_turn"})
    return actions

func apply_action(state: Variant, action: Variant) -> Variant:
    match action["type"]:
        "play_card":
            _play_card(state, action["card"])
        "end_turn":
            _end_turn(state)
    return state

func is_game_over(state: Variant) -> bool:
    for role in state["players"]:
        if state["players"][role]["hp"] <= 0:
            return true
    return state["turn"] >= 200

func get_winner(state: Variant) -> String:
    for role in state["players"]:
        if state["players"][role]["hp"] <= 0:
            var other = "player_2" if role == "player_1" else "player_1"
            return other
    return ""  # draw (timeout)

func get_run_metrics(state: Variant) -> Dictionary:
    return {
        "turns": state["turn"],
        "total_damage_dealt": (
            state["players"]["player_1"]["damage_dealt"]
            + state["players"]["player_2"]["damage_dealt"]
        ),
        "player_1_final_hp": state["players"]["player_1"]["hp"],
        "player_2_final_hp": state["players"]["player_2"]["hp"],
    }

# ... private helpers _build_deck, _draw_cards, _play_card, _end_turn
```

### 8.2 Bot strategies

```gdscript
# game/strategies/aggressive.gd
class_name AggressiveStrategy extends BotStrategy

func choose_action(state: Variant, available_actions: Array) -> Variant:
    # Play the highest-damage card we can afford
    var best_action = null
    var best_damage = -1

    for action in available_actions:
        if action["type"] == "play_card":
            var damage = action["card"].get("damage", 0)
            if damage > best_damage:
                best_damage = damage
                best_action = action

    if best_action:
        return best_action

    # No playable damage cards -- end turn
    return available_actions.back()
```

```gdscript
# game/strategies/defensive.gd
class_name DefensiveStrategy extends BotStrategy

func choose_action(state: Variant, available_actions: Array) -> Variant:
    # Prefer healing/shield cards, then cheapest damage card
    for action in available_actions:
        if action["type"] == "play_card" and action["card"].get("heals", 0) > 0:
            return action

    var cheapest = null
    var cheapest_cost = 999

    for action in available_actions:
        if action["type"] == "play_card" and action["card"]["cost"] < cheapest_cost:
            cheapest_cost = action["card"]["cost"]
            cheapest = action

    if cheapest:
        return cheapest

    return available_actions.back()
```

### 8.3 Running from CLI

```bash
# Quick sanity check: 100 games, aggressive vs defensive
godot --headless --script addons/balance_tester/cli.gd -- \
    --adapter=res://game/adapters/card_game_adapter.gd \
    --strategies=player_1:res://game/strategies/aggressive.gd,player_2:res://game/strategies/defensive.gd \
    --iterations=100 \
    --report=reports/aggro_vs_defense.json

# Overnight: 10,000 games with fixed seed for reproducibility
godot --headless --script addons/balance_tester/cli.gd -- \
    --adapter=res://game/adapters/card_game_adapter.gd \
    --strategies=player_1:res://game/strategies/aggressive.gd,player_2:res://game/strategies/aggressive.gd \
    --iterations=10000 \
    --seed=12345 \
    --report=reports/mirror_match.json
```

### 8.4 GUT balance tests

```gdscript
# test/balance/test_card_balance.gd
extends GutTest

func _make_report(s1: BotStrategy, s2: BotStrategy, n: int = 500) -> BalanceReport:
    var config = SimConfig.new()
    config.iterations = n
    config.game_adapter = CardGameAdapter.new()
    config.strategies = {"player_1": s1, "player_2": s2}
    config.max_turns = 200
    return SimRunner.new().configure(config).run()

func test_mirror_match_is_fair():
    var report = _make_report(AggressiveStrategy.new(), AggressiveStrategy.new())
    # Mirror match should be close to 50/50
    BalanceAssertions.assert_win_rate_between(report, "player_1", 0.43, 0.57)

func test_aggressive_beats_defensive_but_not_by_too_much():
    var report = _make_report(AggressiveStrategy.new(), DefensiveStrategy.new())
    # Aggressive should have an edge, but not dominate
    BalanceAssertions.assert_win_rate_between(report, "player_1", 0.52, 0.70)

func test_games_dont_stall():
    var report = _make_report(DefensiveStrategy.new(), DefensiveStrategy.new())
    # Even defensive vs defensive should finish in reasonable time
    BalanceAssertions.assert_avg_between(report, "turns", 5.0, 50.0)
    BalanceAssertions.assert_median_between(report, "turns", 5.0, 40.0)
```

---

## 9. Addon File Structure

```
addons/balance_tester/
    plugin.cfg
    cli.gd                          # CLI entry point
    core/
        sim_runner.gd               # SimRunner class
        sim_config.gd               # SimConfig data class
        run_result.gd               # RunResult data class
        balance_report.gd           # BalanceReport with stats + JSON serialization
        game_adapter.gd             # Abstract GameAdapter base class
        bot_strategy.gd             # Abstract BotStrategy base class
    strategies/
        random_strategy.gd          # Built-in: random action selection
        first_action_strategy.gd    # Built-in: always pick first action
    assertions/
        balance_assertions.gd       # Statistical assertion functions for GUT
    util/
        stats.gd                    # Mean, median, stddev, percentile math
        cli_parser.gd               # Argument parsing for CLI runner
```

---

## 10. MVP Scope (v0.1)

### Ships in v0.1

| Component | Details |
|-----------|---------|
| **SimRunner** | Sequential execution of N game iterations. Single-threaded. |
| **GameAdapter** | Abstract base class with the interface defined in section 5.2. |
| **BotStrategy** | Abstract base class. Two built-in strategies (Random, FirstAction). |
| **RunResult** | Data class: winner, turns, metrics dict, seed. |
| **BalanceReport** | Aggregation with mean, median, stddev, percentiles. JSON serialization. `save()` to file. |
| **BalanceAssertions** | `assert_win_rate_between`, `assert_avg_between`, `assert_median_between`, `assert_stddev_below`, `assert_no_dominant_strategy`. |
| **CLI runner** | Parse args, instantiate adapter + strategies from paths, run, save report. |
| **RNG seeding** | Configurable seed for reproducible runs. Per-run seed recorded in results. |
| **Max turn safety** | Configurable max turns per run to prevent infinite loops. |
| **plugin.cfg** | Valid Godot addon manifest. |

### Deferred to v0.2+

| Feature | Why deferred |
|---------|-------------|
| **Parallel execution** | Godot's threading model adds complexity. Sequential is good enough for MVP -- 10,000 simple game simulations complete in seconds. |
| **Scene tree integration** | v0.1 works with pure-data game logic (no nodes). v0.2 adds `SceneGameAdapter` that instantiates actual scenes in headless mode. |
| **Live progress callback** | `SimRunner.on_progress(callable)` for progress bars. Not needed for CLI/CI use. |
| **Built-in visualization** | Charts, histograms, HTML reports. v0.1 outputs JSON; users can pipe it into any charting tool. |
| **Matchup matrix** | Auto-run all strategy pairs and output a win-rate matrix. Useful but can be built on top of v0.1 primitives. |
| **Weighted random strategy** | `WeightedStrategy` that assigns weights to action types. Common enough to be built-in but not blocking. |
| **Parameter sweep** | Run the same simulation across a range of game parameters (e.g., starting HP from 20 to 40 in steps of 5) and compare reports. |
| **CI template** | GitHub Actions / GitLab CI YAML templates for running balance tests on push. |
| **GUT plugin auto-registration** | Auto-detect GUT and register assertion helpers. v0.1 requires manual import. |

---

## 11. Success Criteria

v0.1 is successful when:

1. A developer can install the addon into a Godot 4.6+ project, implement `GameAdapter` and `BotStrategy` for their game, and run 1,000 simulations from the CLI in under 60 seconds for a simple card game.
2. The JSON report contains correct summary statistics that match hand-verified samples.
3. Balance assertions can be used in GUT tests and produce clear pass/fail output with meaningful error messages (e.g., "Expected win rate for player_1 between 0.45 and 0.55, got 0.63").
4. The entire addon is fewer than 1,500 lines of GDScript (excluding tests).
5. Zero external dependencies beyond Godot 4.6+ and (optionally) GUT for test integration.

---

## 12. Open Questions

1. **State mutability vs immutability.** Should `apply_action` mutate state in-place or return a new state? Mutable is more natural in GDScript (Dictionaries are reference types). Immutable is safer. v0.1 will document that the adapter owns the state object and can mutate it, but the framework will not mutate it.

2. **Async/coroutine support.** Should `choose_action` support `await`? This would let bots do expensive computation (minimax, MCTS) without blocking. Adds complexity. Defer to v0.2 unless trivial to support.

3. **Multi-action turns.** The current interface assumes one action per call to `choose_action`, with the game loop calling repeatedly until `end_turn`. This works for card games. Some games have simultaneous action selection. Do we need a `choose_actions` (plural) variant? Defer -- the single-action loop covers the MVP use cases.

4. **Metric types.** v0.1 treats all metrics as floats. Some metrics are categorical (e.g., "winning_strategy_type"). Should `RunResult.metrics` support string values? Probably yes in v0.2, with frequency tables in the report.

---

## 13. Prior Art and Differentiation

| Project | Platform | Difference from GodotBalanceTester |
|---------|----------|-----------------------------------|
| **Unity ML-Agents** | Unity | Full ML training framework. GBT is simpler -- no neural nets, just scripted bots and stats. Lower barrier to entry. |
| **OpenSpiel** | C++/Python | Research framework for game theory. Not integrated with any game engine. |
| **Ludii** | Java | General game system for combinatorial games. Academic focus, not for production game dev. |
| **Monte Carlo tree search libs** | Various | Algorithm libraries, not testing frameworks. GBT could use MCTS as a bot strategy. |
| **GUT / WAT** | Godot | Unit test frameworks. No simulation runner, no statistical assertions, no balance reporting. GBT complements these. |

GodotBalanceTester's niche: **the simplest possible bridge between "I have game logic in Godot" and "I have statistical evidence about my game's balance."** Not ML. Not research. Just bots, runs, and numbers.
