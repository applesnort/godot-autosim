# godot-autosim

Automated game simulation and balance testing for Godot 4.6+.

## Why

You're building a roguelike, card game, or strategy game. You tweaked enemy HP from 50 to 55. Did that break the difficulty curve? Did it make the boss unbeatable? Did it make block cards useless?

**Without godot-autosim:** play the game 20 times, guess, tweak, repeat.

**With godot-autosim:** run 1000 simulations in 5 seconds, get data:

| Strategy | Wins | Win Rate | Avg Turns |
|---|---|---|---|
| Aggressive | 450/1000 | 45.0% | 8.2 |
| Defensive | 380/1000 | 38.0% | 11.4 |
| Random | 120/1000 | 12.0% | 6.1 |

## How It Works

You write two small scripts. The **adapter** teaches the framework how your game works — what actions are available, how to apply them, and when the game is over. The **bot** decides which action to take each turn. The framework handles the rest: it plays your game thousands of times, collects the results, and gives you a report with win rates, averages, distributions, and anything else you want to track.

```
Adapter (your game rules) + Bot (play strategy) → Runner (1000 games) → Report (win rates, metrics)
```

This runs headless — no rendering, no physics, no scene tree needed. A thousand games finish in seconds.

## Quick Start

### 1. Install

Copy `addons/godot_autosim/` into your project's `addons/` folder.

### 2. Write an adapter

The adapter is a script that describes your game to the framework. You extend `AutoSimGameAdapter` and implement a handful of methods. Here's a card game example:

```gdscript
extends AutoSimGameAdapter

func create_initial_state() -> Variant:
    return {hp = 80, enemy_hp = 50, hand = [...]}

func get_roles() -> Array[String]:
    return ["player"]

func get_current_role(state: Variant) -> String:
    return "player"

func get_available_actions(state: Variant) -> Array:
    var actions = []
    for card in state.hand:
        actions.append({action = "play", card = card})
    actions.append({action = "end_turn"})
    return actions

func apply_action(state: Variant, action: Variant) -> Variant:
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

The framework calls these methods in a loop: get actions → bot picks one → apply it → repeat until game over. You don't manage the loop yourself.

### 3. Write a bot

The bot picks an action from the list your adapter provides. Different bots let you test different play styles:

```gdscript
extends AutoSimBotStrategy

func choose_action(state: Variant, available_actions: Array) -> Variant:
    var best = null
    for action in available_actions:
        if action.action == "play" and action.card.damage > 0:
            if best == null or action.card.damage > best.card.damage:
                best = action
    return best if best else available_actions.back()
```

Write as many bots as you want — aggressive, defensive, random, greedy. Comparing them is how you find balance problems.

### 4. Run it

```gdscript
var config = AutoSimConfig.create(MyAdapter.new(), {"player": AggressiveBot.new()}, 1000)
var report = AutoSimRunner.run(config)
print(report.summary())  # "1000 runs | 72.3% win rate | avg 5.4 turns"
```

Or from the command line:

```bash
godot --headless --script addons/godot_autosim/cli/cli.gd -- \
  --adapter=res://my_adapter.gd \
  --strategy=res://aggressive_bot.gd \
  --iterations=1000 \
  --output=balance_report.json
```

## Reading the Report

Once the runner finishes, you get a `BalanceReport` with everything you need to understand your game's balance:

```gdscript
report.win_rate("player")         # 0.723 — how often this strategy wins
report.avg("hp_remaining")        # 42.1 — mean across all runs
report.median("turns")            # 5.0 — middle value (less sensitive to outliers than avg)
report.stddev("damage_taken")     # 12.3 — how consistent the experience is
report.percentile("turns", 95)    # 12.0 — worst-case game length
report.distribution("turns", 5)   # histogram buckets for visualization
```

High stddev means some runs are wildly different from others — a sign of feast-or-famine balance. If `avg` and `median` diverge, you've got outlier runs pulling the average.

Export the full data as JSON for external analysis:

```gdscript
report.save("balance_report.json")  # every run with all metrics
```

## Balance Tests in CI

The real power is catching regressions automatically. If you use [GUT](https://github.com/bitwes/Gut) (Godot Unit Test — the most popular testing framework for Godot, similar to Jest or pytest), the framework includes assertion helpers that turn balance data into pass/fail tests. If you don't use GUT, skip this section — everything above works without it.

```gdscript
extends GutTest

func test_boss_is_beatable_but_not_trivial():
    var config = AutoSimConfig.create(MyAdapter.new(), {"player": SmartBot.new()}, 500)
    var report = AutoSimRunner.run(config)

    # Win rate should be 40-70% — challenging but fair
    AutoSimAssertions.assert_win_rate_between(self, report, "player", 0.4, 0.7)

    # Fights should last 5-10 turns — long enough for decisions to matter
    AutoSimAssertions.assert_avg_between(self, report, "turns", 5.0, 10.0)

func test_no_dominant_strategy():
    var adapter = MyAdapter.new()
    var reports = {}
    for bot_name in ["aggressive", "defensive", "random"]:
        var bot = load("res://bots/%s_bot.gd" % bot_name).new()
        reports[bot_name] = AutoSimRunner.run(
            AutoSimConfig.create(adapter, {"player": bot}, 500))

    # No single strategy should win more than 95% — that means the others are pointless
    AutoSimAssertions.assert_no_dominant_strategy(self, reports, 0.95)
```

Now every PR that touches combat numbers runs these tests. You'll know immediately if a change broke the difficulty curve.

The full set of assertions:

- **`assert_win_rate_between`** — win rate falls in a range (e.g., 40-70%)
- **`assert_avg_between`** — average of any metric falls in a range
- **`assert_median_between`** — same but for median (more robust to outliers)
- **`assert_stddev_below`** — experience is consistent enough (low variance)
- **`assert_no_dominant_strategy`** — no single strategy makes all others irrelevant

## Async Games

If your game uses `await` in its turn logic (coroutines, signal-driven combat), use the async variants. The adapter interface is identical except `apply_action` becomes `apply_action_async`:

```gdscript
extends AutoSimAsyncGameAdapter

func apply_action_async(state: Variant, action: Variant) -> Variant:
    await state.play_card(action["card"])
    return state
```

The runner needs to be in the scene tree since it awaits each step:

```gdscript
var runner = AutoSimAsyncRunner.new()
add_child(runner)
var report = await runner.run(config)
runner.queue_free()
```

## Two Adapter Approaches

### Direct Adapter

If your game logic is separated from rendering — pure functions, no physics, no Timer nodes — your adapter calls the real game code directly. This gives exact fidelity:

```gdscript
func apply_action(state, action):
    state.play_card(action["card"])
    return state
```

### Mathematical Model

If your game uses Area2D collision, NavigationAgent2D, AnimationPlayer, or Timer-based cooldowns, those systems crash without a scene tree. Instead of fighting the engine, extract the balance-relevant numbers and reimplement the core loop as pure math:

```gdscript
func _find_target(turret, enemies):
    for enemy in enemies:
        if turret["pos"].distance_to(enemy["pos"]) <= turret["range"]:
            return enemy
    return null
```

**Why this works:** Balance problems are about numbers — damage too high, cost too low, scaling too steep. The tower defense adapter below found a 144x cost-efficiency imbalance between turret types without ever loading a tilemap. The auto-battler adapter found that one equipped unit beats three unequipped without instantiating a single Area2D.

**What it trades:** Physics edge cases (projectile dodging, pathfinding quirks, collision overlaps). For balance testing, that's a good trade — you get hundreds of runs per second instead of fighting engine dependencies.

| Your game's architecture | Adapter approach |
|---|---|
| Logic separated from nodes (data-driven) | Direct — call real game code |
| Game uses `await` / coroutines | Direct with `AutoSimAsyncGameAdapter` + `AutoSimAsyncRunner` |
| Game uses physics/navigation/timers | Mathematical model |
| C# simulation layer | C# bridge class + GDScript adapter |

## Validated on Open-Source Games

We've tested godot-autosim against six games across different genres to verify the framework works beyond our own projects. Clone any of these and try the adapter yourself.

### Built-in: Card Battle

Ships in `examples/card_battle/`. A minimal deckbuilder with attack/block/bash cards vs a repeating damage pattern. Three bot strategies included.

| Strategy | Win Rate | Avg Turns | Notes |
|---|---|---|---|
| Aggressive | 100% | 10.7 | Fastest — plays damage cards first |
| Defensive | 100% | 33.4 | 3x slower — blocks before attacking |
| Random | 100% | 19.9 | Even random wins — enemy is too weak |

```bash
godot --headless --script addons/godot_autosim/cli/cli.gd -- \
  --adapter=res://addons/godot_autosim/examples/card_battle/card_battle_adapter.gd \
  --strategy=res://addons/godot_autosim/examples/card_battle/aggressive_bot.gd \
  --iterations=500
```

### Tower Defense — [quiver-dev/tower-defense-godot4](https://github.com/quiver-dev/tower-defense-godot4)

Tile-based tower defense with economy, waves, and multiple turret types. Mathematical model adapter.

| Strategy | Win Rate | Kills | Finding |
|---|---|---|---|
| Gatling-first | 100% | 190 | Objective untouched |
| Mixed | 100% | 190 | Objective untouched |
| Missile-first | 0% | 42 | Objective destroyed |

**Balance issue found:** 144x DPS/cost imbalance — gatling (180 DPS, 250g) vs missile (4 DPS, 800g). Any strategy that doesn't prioritize gatlings loses.

### Auto-Battler — [guladam/godot_autobattler_course](https://github.com/guladam/godot_autobattler_course)

Singleplayer auto-battler with units, abilities, traits, and items. Mathematical model adapter.

| Matchup | Result |
|---|---|
| 3 Bjorn + 2 Robin vs 5 Zombie | 100% player win |
| 2 Robin vs 5 Zombie | 0% player win |
| 2 Bjorn (tier 2) vs 5 Bjorn (tier 1) | 7.4% player win |
| 1 Bjorn (sword+gloves) vs 3 Zombie | 100% player win |

**Balance issue found:** Items swing outcomes from 0% to 100% — one equipped unit beats three unequipped.

### Deckbuilder — [DesirePathGames/Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot)

Full roguelike deckbuilder with 20+ cards, energy system, and status effects. Mathematical model adapter.

| Strategy | Win Rate | Avg Turns | HP Remaining |
|---|---|---|---|
| Smart | 100% | 5.6 | 47.0 |
| Random | 99.7% | — | — |

**Balance issue found:** Basic Attack at 25 damage is wildly overtuned (75 DPS/turn vs 20-40 HP enemies). Even random play wins 99.7%.

### 3D Turn-Based Combat — [Cute-Fame-Studio/3D-TurnBasedCombat](https://github.com/Cute-Fame-Studio/3D-TurnBasedCombat)

3D RPG with `CharacterBody3D` battlers, elemental damage, skills, and multi-unit parties. Mathematical model adapter.

| Matchup | Result | Finding |
|---|---|---|
| Warriors vs Mages (1v1) | 100% warrior | Mages too squishy (80 HP / 4 def) |
| Balanced (W+M+H) vs 3x Warriors | 98.5% balanced | Healers enable infinite sustain |
| Fire Mages vs Water Mages | 100% fire | Element wheel inverted from intuition |
| Party vs Dragon Boss | 100% party | Healer sustain trivializes boss fights |

**Balance issues found:** Healers are overpowered (50 HP heal, 15 SP cost, 7 SP/turn regen). Element wheel function contradicts its own comments — fire beats water, not vice versa.

### Roguelike — [statico/godot-roguelike-example](https://github.com/statico/godot-roguelike-example)

Turn-based roguelike with d20 combat, BSP dungeon generation, and monster scaling. Mathematical model adapter.

| Strategy | Avg Floors | Kills | Turns Survived |
|---|---|---|---|
| Smart | 1.5 | 2.3 | 267 |
| Random | 0.0 | 0.5 | 686 |

**Finding:** Smart bot clears floors but dies faster (aggressive engagement). Neither bot completes the full 20-floor dungeon — the d20 combat system is genuinely lethal at depth with monster strength scaling 1.25x per floor.

## Roadmap

- **Godot 4.5 support** — currently requires 4.6+. Backporting to 4.5 would cover the majority of active Godot projects.
- **Multi-role games** — the framework supports multiple roles already, but needs a proper 2-player example (PvP matchup testing, asymmetric balance).
- **Report visualization** — HTML or Godot-native dashboard for viewing distributions, win rate trends across parameter sweeps.
- **Parameter sweep runner** — vary a game parameter (enemy HP, card cost, spawn rate) across a range and plot win rate as a curve. Find the sweet spot without manual iteration.
- **Adapter generator** — CLI tool or editor plugin that scaffolds an adapter from your game's existing scripts.

## Requirements

- Godot 4.6+

## License

MIT
