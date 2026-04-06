# Contributing to godot-autosim

## Setup

1. Clone the repo
2. Install [GUT](https://github.com/bitwes/Gut) 9.x into `addons/gut/`
3. Open the project in Godot 4.6+
4. Enable both plugins (godot_autosim + GUT) in Project Settings → Plugins

## Running Tests

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## Project Structure

```
addons/godot_autosim/
  core/           # Framework classes (adapter, runner, report, assertions)
  cli/            # Headless CLI runner
  plugin.cfg
examples/
  card_battle/    # Built-in example game with 3 bot strategies
tests/            # GUT tests for the framework
```

## Adding Tests

- Place test files in `tests/` with the `test_` prefix
- Extend `GutTest`
- Use `_make_config()` helpers for concise test setup
- Run the full suite before submitting

## Pull Requests

- One logical change per PR
- Tests must pass (`0 failing` in GUT output)
- No new orphan warnings beyond the existing baseline
- Update README if adding user-facing features

## Code Style

- GDScript with static typing (explicit type annotations on all declarations)
- `class_name` prefix: `AutoSim` for framework classes (e.g., `AutoSimRunner`)
- Dictionary state over inner classes (GDScript inner classes don't roundtrip through Variant)
- `cleanup_state()` pattern for any adapter that creates Nodes
