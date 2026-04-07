# godot-autosim

Automated game simulation and balance testing for Godot 4.6+.

You tweaked enemy HP from 50 to 55. Did that break the difficulty curve? Instead of playing 20 times to find out, run 1000 simulations in 5 seconds and get data.

## Quick Start

### 1. Install

Copy `addons/godot_autosim/` into your project's `addons/` folder.

### 2. Describe your game

Tell the framework your game's rules using lambdas:

```gdscript
var adapter = AutoSimQuickAdapter.from({
    setup = func():
        return {hp = 80, enemy_hp = 50, turn = 0},
    actions = func(state):
        return ["attack", "defend", "end_turn"],
    apply = func(state, action):
        match action:
            "attack": state["enemy_hp"] -= 12
            "defend": state["hp"] += 3
            "end_turn": state["hp"] -= 8
        state["turn"] += 1
        return state,
    done = func(state):
        return state["hp"] <= 0 or state["enemy_hp"] <= 0,
    winner = func(state):
        return "player" if state["enemy_hp"] <= 0 else "",
})
```

### 3. Run it

```gdscript
var report = AutoSimRunner.run(
    AutoSimConfig.create(adapter, {"player": AutoSimRandomBot.new()}, 1000))

print(report.summary())  # "1000 runs | 92.3% win rate | avg 5.4 turns"
```

That's it. A random bot plays your game a thousand times and you see how often it wins.

### 4. From the command line

If you have an adapter script saved as a `.gd` file, you don't need to write any runner code:

```bash
godot --headless --script addons/godot_autosim/cli/cli.gd -- \
  --adapter=res://my_adapter.gd \
  --iterations=1000
```

The bot defaults to random. Override with `--strategy=greedy:damage` or point to your own script.

## What you learn from the report

```gdscript
report.win_rate("player")         # 0.723 — how often this strategy wins
report.avg("hp_remaining")        # 42.1 — mean across all runs
report.median("turns")            # 5.0 — middle value, less skewed by outliers
report.stddev("damage_taken")     # 12.3 — how consistent the experience is
report.save("balance_report.json") # export everything for external analysis
```

If `avg` and `median` diverge, you have outlier runs pulling the average. High `stddev` means feast-or-famine balance.

## Parameter sweeps

Don't guess. Sweep a value across a range and see exactly where balance breaks:

```gdscript
var result = AutoSimSweepRunner.run(
    adapter, {"player": AutoSimRandomBot.new()},
    "enemy_hp", [30, 50, 75, 100, 150, 200])

print(result.table())
```

```
enemy_hp | Win Rate | Avg Turns
---------+----------+----------
30.0     |   100.0% |       5.3
50.0     |   100.0% |      10.7
75.0     |   100.0% |      15.7
100.0    |   100.0% |      20.6
150.0    |   100.0% |      30.6
200.0    |    28.0% |      40.5
```

Find the exact tipping point:

```gdscript
result.find_threshold("player", 0.5)  # → 175.0 (interpolated)
```

From the CLI:

```bash
godot --headless --script addons/godot_autosim/cli/cli.gd -- \
  --adapter=res://my_adapter.gd \
  --sweep=enemy_hp:30,50,75,100,150,200
```

## Built-in bots

**`AutoSimRandomBot`** — picks a random action every turn. Use as a baseline: if random play wins too often, your game is too easy.

**`AutoSimGreedyBot`** — picks the action with the highest value for a metric you specify. `AutoSimGreedyBot.new("damage")` always plays the highest-damage option.

Write your own bot when you need strategy-specific testing:

```gdscript
extends AutoSimBotStrategy

func choose_action(state: Variant, available_actions: Array) -> Variant:
    # Your strategy logic here
    return available_actions[0]
```

## Going deeper

### Full adapter class

For complex games, extend `AutoSimGameAdapter` instead of using `QuickAdapter`. This gives you full control:

```gdscript
extends AutoSimGameAdapter

func create_initial_state() -> Variant:
    return {hp = 80, enemy_hp = 50, hand = [...]}

func get_roles() -> Array[String]:
    return ["player"]

func get_current_role(state: Variant) -> String:
    return "player"

func get_available_actions(state: Variant) -> Array:
    # Return what the bot can do right now
    return [...]

func apply_action(state: Variant, action: Variant) -> Variant:
    # Execute the action and return updated state
    return state

func is_game_over(state: Variant) -> bool:
    return state.hp <= 0 or state.enemy_hp <= 0

func get_winner(state: Variant) -> String:
    return "player" if state.enemy_hp <= 0 else ""

func get_run_metrics(state: Variant) -> Dictionary:
    return {hp_remaining = state.hp}
```

### Async games

If your game uses `await` in its turn logic, use `AutoSimAsyncGameAdapter` and `AutoSimAsyncRunner`:

```gdscript
extends AutoSimAsyncGameAdapter

func apply_action_async(state: Variant, action: Variant) -> Variant:
    await state.play_card(action["card"])
    return state
```

```gdscript
var runner = AutoSimAsyncRunner.new()
add_child(runner)
var report = await runner.run(config)
runner.queue_free()
```

### Balance tests in CI

If you use [GUT](https://github.com/bitwes/Gut) (Godot's most popular test framework), catch balance regressions automatically:

```gdscript
extends GutTest

func test_boss_is_beatable_but_not_trivial():
    var report = AutoSimRunner.run(
        AutoSimConfig.create(MyAdapter.new(), {"player": SmartBot.new()}, 500))
    AutoSimAssertions.assert_win_rate_between(self, report, "player", 0.4, 0.7)
```

Assertions: `assert_win_rate_between`, `assert_avg_between`, `assert_median_between`, `assert_stddev_below`, `assert_no_dominant_strategy`.

### Direct vs mathematical model adapters

If your game logic is separated from rendering (pure functions, no physics), your adapter calls your real game code directly. If your game uses Area2D, NavigationAgent2D, or timers, build a mathematical model instead — reimplement the balance-relevant mechanics as pure math. Balance problems are about numbers, not pixels.

## Validated on 6 open-source games

| Game | Genre | Adapter Type | Key Finding |
|---|---|---|---|
| [Card Battle](addons/godot_autosim/examples/card_battle/) (built-in) | Deckbuilder | Direct | 100% win with random — enemy too weak |
| [Tower Defense](https://github.com/quiver-dev/tower-defense-godot4) | TD | Math model | 144x DPS/cost imbalance between turrets |
| [Auto-Battler](https://github.com/guladam/godot_autobattler_course) | Auto-battler | Math model | Items swing 0%→100% win rate |
| [Slay The Robot](https://github.com/DesirePathGames/Slay-The-Robot) | Deckbuilder | Math model | 99.7% random win — Basic Attack overtuned |
| [3D Combat](https://github.com/Cute-Fame-Studio/3D-TurnBasedCombat) | 3D RPG | Math model | Healers OP, element wheel inverted |
| [Roguelike](https://github.com/statico/godot-roguelike-example) | Roguelike | Math model | d20 combat lethal at depth, 0% completion |

## Roadmap

- **Godot 4.5 support** — backport to cover more active projects
- **Multi-role example** — 2-player PvP matchup testing
- **Report visualization** — HTML dashboard for distributions and sweep curves
- **Genre adapters** — pre-built adapters for common game types (turn-based combat, deckbuilder)

## Requirements

- Godot 4.6+

## License

MIT
