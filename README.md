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

## Tested on Open-Source Games

godot-autosim ships with a built-in card battle example and has been validated against
open-source Godot games of different types. Clone any of these and try the adapter yourself.

### Built-in: Card Battle (2D, Turn-Based)
Ships in `examples/card_battle/`. A minimal deckbuilder with attack/block/bash cards
vs an enemy with a repeating damage pattern. Three bot strategies included.

```bash
godot --headless --script addons/godot_autosim/cli/cli.gd -- \
  --adapter=res://examples/card_battle/card_battle_adapter.gd \
  --strategy=res://examples/card_battle/aggressive_bot.gd \
  --iterations=500
```

```
Strategy comparison (50 HP enemy, 100 runs each):
  Aggressive: 100% win | avg 10.7 turns
  Defensive:  100% win | avg 33.4 turns (3× slower!)
  Random:     100% win | avg 19.9 turns
```

### Outpost Assault — Tower Defense ([quiver-dev/tower-defense-godot4](https://github.com/quiver-dev/tower-defense-godot4))
Tile-based tower defense with economy, waves, and multiple turret types. Uses
mathematical model adapter (game is physics-coupled).

```
Strategy comparison (200 runs each, seed=42):
  Aggressive (gatling-first): 100% win | 190 kills | objective untouched
  Balanced (mixed):           100% win | 190 kills | objective untouched
  Defensive (missile-first):    0% win |  42 kills | objective destroyed

Finding: 144× DPS/cost imbalance — gatling (180 DPS, 250g) vs missile (4 DPS, 800g).
Any strategy that doesn't prioritize gatlings loses.
```

### AutoBattler Course ([guladam/godot_autobattler_course](https://github.com/guladam/godot_autobattler_course))
Singleplayer auto-battler with units, abilities, traits, and items. Mathematical
model adapter with tick-based combat simulation.

```
Sample matchups (500 iterations each):
  3 Bjorn + 2 Robin vs 5 Zombie:       100% player win
  2 Robin vs 5 Zombie:                   0% player win
  2 Bjorn (tier 2) vs 5 Bjorn (tier 1):  7.4% player win
  1 Bjorn (sword+gloves) vs 3 Zombie:  100% player win

Finding: items dramatically shift outcomes — one equipped unit beats three unequipped.
```

### Slay The Robot — Deckbuilder ([DesirePathGames/Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot))
Full roguelike deckbuilder with 20+ cards, energy system, status effects.
Mathematical model adapter (game uses scene-tree-coupled action system).

```
49/49 tests passing. Strategy comparison:
  SmartBot:  100% win | avg 5.6 turns | HP remaining: 47.0
  RandomBot: 99.7% win

Finding: Basic Attack at 25 damage is wildly overtuned (75 DPS/turn vs 20-40 HP enemies).
Even random play wins 99.7%.
```

## Requirements

- Godot 4.6+
- Your game logic must be separable from rendering (no `_process` frame dependencies)
- [GUT](https://github.com/bitwes/Gut) for running balance test assertions (optional)

## License

MIT
