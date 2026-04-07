# Changelog

All notable changes to godot-autosim will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.3.0] - Unreleased

### Added
- Parameter sweep runner (`AutoSimSweepRunner`) — vary a single adapter property across a range of values, get a comparison table and threshold finding
- `AutoSimSweepResult` with `table()`, `find_threshold()`, `get_report()`, JSON export
- CLI `--sweep` flag for running sweeps from the command line
- Built-in bots: `AutoSimRandomBot` (random action) and `AutoSimGreedyBot` (maximize a metric)
- `AutoSimQuickAdapter` — define games with lambdas instead of a class, supports property forwarding for sweeps
- CLI defaults to random bot when `--strategy` is omitted
- CLI supports `--strategy=random` and `--strategy=greedy:<key>` shortcuts
- 40 new tests (79 total)

## [0.2.0] - 2026-04-06

### Added
- Tests for `assert_no_dominant_strategy`, `assert_median_between`, `assert_stddev_below`
- Tests for `BalanceReport.save()` (JSON file export)
- Deep seed reproducibility tests (metric-level comparison)
- CLI runner end-to-end verification
- Async adapter section in README quick-start and API reference
- Open-source validation: 3D turn-based combat (CharacterBody3D game)
- Open-source validation: roguelike dungeon crawler (d20 combat, BSP dungeons)
- `CONTRIBUTING.md`
- `CHANGELOG.md`
- GitHub Actions CI workflow

### Changed
- GUT is no longer bundled — documented as external prerequisite

## [0.1.0] - 2026-04-06

### Added
- Core framework: `AutoSimGameAdapter`, `AutoSimBotStrategy`, `AutoSimRunner`, `AutoSimConfig`, `AutoSimRunResult`, `AutoSimBalanceReport`
- Async variants: `AutoSimAsyncGameAdapter`, `AutoSimAsyncRunner`
- Balance assertions: `AutoSimAssertions` with 5 assertion helpers for GUT tests
- CLI runner for headless invocation (`cli.gd`)
- Built-in card battle example with 3 bot strategies (aggressive, defensive, random)
- 15 framework tests
- Validated against 4 open-source games: tower defense, auto-battler, deckbuilder, card battle
- README with quick-start, API reference, and "Two Adapter Approaches" guide
- PRD spec (`docs/prd.md`)
- MIT license
