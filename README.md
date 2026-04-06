# godot-autosim

Automated game simulation and balance testing for Godot 4.6+.

Run thousands of headless game simulations with bot strategies. Collect win rates, turn distributions, and custom metrics. Catch balance regressions in CI.

## Why

You're building a roguelike, card game, or strategy game. You tweaked enemy HP from 50 to 55. Did that break the difficulty curve? Did it make the boss unbeatable? Did it make block cards useless?

**Without godot-autosim:** play the game 20 times, guess, tweak, repeat.

**With godot-autosim:** run 1000 simulations in 5 seconds, get data:

```
Aggressive vs Boss [10 cards]: 450/1000 wins (45.0%) | avg 8.2 turns
Defensive vs Boss [10 cards]: 380/1000 wins (38.0%) | avg 11.4 turns
Random vs Boss [10 cards]: 120/1000 wins (12.0%) | avg 6.1 turns
```

## Quick Start

### 1. Install

Copy `addons/godot_autosim/` into your project's `addons/` folder.

### 2. Create a Game Adapter

Extend `AutoSimGameAdapter` to bridge your game to the framework:

```gdscript
# my_game_adapter.gd
extends AutoSimGameAdapter

func create_initial_state() -> Variant:
    # Return a fresh game state object
    return {hp = 80, enemy_hp = 50, hand = [...]}

func get_roles() -> Array[String]:
    return ["player"]

func get_current_role(state: Variant) -> String:
    return "player"

func get_available_actions(state: Variant) -> Array:
    # Return what the bot can do right now
    var actions = []
    for card in state.hand:
        actions.append({action = "play", card = card})
    actions.append({action = "end_turn"})
    return actions

func apply_action(state: Variant, action: Variant) -> Variant:
    # Mutate game state based on chosen action
    match action.action:
        "play": play_card(state, action.card)
        "end_turn": resolve_enemy_turn(state)
    return state

func is_game_over(state: Variant) -> bool:
    return state.hp <= 0 or state.enemy_hp <= 0

func get_winner(state: Variant) -> String:
    return "player" if state.enemy_hp <= 0 else ""

func get_run_metrics(state: Variant) -> Dictionary:
    return {hp_remaining = state.hp, damage_taken = 80 - state.hp}
```

### 3. Create a Bot Strategy

Extend `AutoSimBotStrategy` to define how the bot plays:

```gdscript
# aggressive_bot.gd
extends AutoSimBotStrategy

func choose_action(state: Variant, available_actions: Array) -> Variant:
    # Play highest damage card, or end turn
    var best = null
    for action in available_actions:
        if action.action == "play" and action.card.damage > 0:
            if best == null or action.card.damage > best.card.damage:
                best = action
    return best if best else available_actions.back()  # end_turn
```

### 4. Run Simulations

**From code:**

```gdscript
var adapter = MyGameAdapter.new()
var bot = AggressiveBot.new()
var config = AutoSimConfig.create(adapter, {"player": bot}, 1000)
var report = AutoSimRunner.run(config)

print(report.summary())              # "1000 runs | 72.3% win rate | avg 5.4 turns"
print(report.win_rate("player"))      # 0.723
print(report.avg("hp_remaining"))     # 42.1
print(report.median("turns"))         # 5.0
print(report.stddev("damage_taken"))  # 12.3
```

**From CLI:**

```bash
godot --headless --script addons/godot_autosim/cli/cli.gd -- \
  --adapter=res://my_game_adapter.gd \
  --strategy=res://aggressive_bot.gd \
  --iterations=1000 \
  --output=balance_report.json
```

### 5. Balance Tests (with GUT)

```gdscript
# test_balance.gd
extends GutTest

func test_boss_is_beatable_but_not_trivial():
    var adapter = MyGameAdapter.new()
    var config = AutoSimConfig.create(adapter, {"player": SmartBot.new()}, 500)
    var report = AutoSimRunner.run(config)

    # Win rate should be 40-70% — challenging but fair
    AutoSimAssertions.assert_win_rate_between(self, report, "player", 0.4, 0.7)

    # Fights should last 5-10 turns — long enough for decisions to matter
    AutoSimAssertions.assert_avg_between(self, report, "turns", 5.0, 10.0)

func test_skill_expression():
    var adapter = MyGameAdapter.new()

    var smart_report = AutoSimRunner.run(
        AutoSimConfig.create(adapter, {"player": SmartBot.new()}, 500))
    var random_report = AutoSimRunner.run(
        AutoSimConfig.create(adapter, {"player": RandomBot.new()}, 500))

    # Smart bot should significantly outperform random
    var spread = smart_report.win_rate("player") - random_report.win_rate("player")
    assert_gt(spread, 0.15, "Skill should matter — 15%+ spread expected")
```

## API Reference

### AutoSimGameAdapter (you implement)

| Method | Purpose |
|---|---|
| `create_initial_state() -> Variant` | Fresh game state for each run |
| `get_roles() -> Array[String]` | Player role names |
| `get_current_role(state) -> String` | Whose turn is it |
| `get_available_actions(state) -> Array` | What can the bot do |
| `apply_action(state, action) -> Variant` | Execute chosen action |
| `is_game_over(state) -> bool` | Has the game ended |
| `get_winner(state) -> String` | Who won (or "" for loss/draw) |
| `get_run_metrics(state) -> Dictionary` | Custom metrics to track |

### AutoSimBotStrategy (you implement)

| Method | Purpose |
|---|---|
| `reset()` | Called at start of each run |
| `choose_action(state, actions) -> Variant` | Pick an action from available options |

### AutoSimRunner (framework provides)

| Method | Purpose |
|---|---|
| `AutoSimRunner.run(config) -> AutoSimBalanceReport` | Run all simulations |

### AutoSimBalanceReport (framework provides)

| Method | Purpose |
|---|---|
| `win_rate(role) -> float` | Win percentage (0.0 - 1.0) |
| `avg(metric) -> float` | Mean of a tracked metric |
| `median(metric) -> float` | Median value |
| `stddev(metric) -> float` | Standard deviation |
| `percentile(metric, p) -> float` | Nth percentile |
| `distribution(metric, buckets) -> Array` | Histogram data |
| `summary() -> String` | Human-readable one-liner |
| `to_json() -> String` | Full JSON report |
| `save(path) -> Error` | Write JSON to file |

### AutoSimAssertions (for GUT tests)

| Method | Purpose |
|---|---|
| `assert_win_rate_between(test, report, role, low, high)` | Win rate in range |
| `assert_avg_between(test, report, metric, low, high)` | Average in range |
| `assert_median_between(test, report, metric, low, high)` | Median in range |
| `assert_stddev_below(test, report, metric, max)` | Consistency check |
| `assert_no_dominant_strategy(test, reports, max_wr)` | No single strategy dominates |

## Examples

The `examples/` folder contains a complete card battle game with three bot strategies:

```bash
# Run the built-in example
godot --headless --script addons/godot_autosim/cli/cli.gd -- \
  --adapter=res://examples/card_battle/card_battle_adapter.gd \
  --strategy=res://examples/card_battle/aggressive_bot.gd \
  --iterations=500
```

## Validated on Real Games

godot-autosim has been tested against real, shipping games — not just toy examples.

### Kitchen Cardgame (Card Roguelike)
STS-style deckbuilder with async combat (`await` in `play_card`). Uses `AutoSimAsyncGameAdapter`.

```
SMART vs Breakfast Rush: 100% win | avg 2.5 turns | HP remaining: 73.9/80
SMART vs Boss:           100% win | avg 7.1 turns | HP remaining: 57.4/80
RANDOM vs Boss:          100% win | avg 7.6 turns | HP remaining: 56.9/80

Finding: game is unlosable — 100% win rate with ANY strategy including random.
Skill spread: 0% (no difference between smart and random play).
```

### Dark Energy / Edgefall (Wave Survival)
Vampire Survivors-style with 20 waves, weapons, upgrades. Uses sync `AutoSimGameAdapter` wrapping existing `FastSimulator`.

```
Strategy comparison (Normal difficulty, 60 runs):
  Balanced:   18.3% win | avg wave 10.0
  Aggressive:  0.0% win | avg wave 6.8
  Defensive:  40.0% win | avg wave 13.5

Difficulty scaling:
  Easy:    93.3% win
  Normal:  18.3% win
  Hard:     1.7% win
  Intense:  0.0% win

Finding: defensive strategy dominates, aggressive is non-viable.
Death cliff at waves 6-8. Easy→Normal gap too steep.
```

### NHL95 (Hockey Simulation)
Real-time hockey with deterministic C# simulation layer. `Sim.Advance(state, input)` called per frame. C# adapter bridges to framework.

*(Results pending — adapter being built)*

## Requirements

- Godot 4.6+
- Your game logic must be separable from rendering (no `_process` frame dependencies)
- [GUT](https://github.com/bitwes/Gut) for running balance test assertions (optional)

## License

MIT
