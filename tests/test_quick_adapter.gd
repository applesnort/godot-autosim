extends GutTest


func _make_combat_adapter() -> AutoSimQuickAdapter:
	return AutoSimQuickAdapter.from({
		setup = func():
			return {hp = 80, enemy_hp = 50, turn = 0},
		actions = func(state: Variant) -> Array:
			if state["hp"] <= 0 or state["enemy_hp"] <= 0:
				return []
			return ["attack", "defend", "end_turn"],
		apply = func(state: Variant, action: Variant) -> Variant:
			match action:
				"attack":
					state["enemy_hp"] -= 12
				"defend":
					state["hp"] += 3
				"end_turn":
					state["hp"] -= 8
			state["turn"] += 1
			return state,
		done = func(state: Variant) -> bool:
			return state["hp"] <= 0 or state["enemy_hp"] <= 0 or state["turn"] >= 50,
		winner = func(state: Variant) -> String:
			return "player" if state["enemy_hp"] <= 0 else "",
	})


# === AutoSimQuickAdapter ===

func test_quick_adapter_creates_state() -> void:
	var adapter := _make_combat_adapter()
	var state = adapter.create_initial_state()
	assert_not_null(state)
	assert_eq(state["hp"], 80)
	assert_eq(state["enemy_hp"], 50)


func test_quick_adapter_get_roles() -> void:
	var adapter := _make_combat_adapter()
	var roles := adapter.get_roles()
	assert_eq(roles.size(), 1)
	assert_eq(roles[0], "player")


func test_quick_adapter_get_actions() -> void:
	var adapter := _make_combat_adapter()
	var state = adapter.create_initial_state()
	var actions := adapter.get_available_actions(state)
	assert_eq(actions.size(), 3)
	assert_true(actions.has("attack"))
	assert_true(actions.has("defend"))


func test_quick_adapter_apply_action() -> void:
	var adapter := _make_combat_adapter()
	var state = adapter.create_initial_state()
	state = adapter.apply_action(state, "attack")
	assert_eq(state["enemy_hp"], 38, "Attack should deal 12 damage")


func test_quick_adapter_game_over() -> void:
	var adapter := _make_combat_adapter()
	var state = adapter.create_initial_state()
	assert_false(adapter.is_game_over(state))
	state["enemy_hp"] = 0
	assert_true(adapter.is_game_over(state))


func test_quick_adapter_winner() -> void:
	var adapter := _make_combat_adapter()
	var state = {hp = 80, enemy_hp = 0, turn = 5}
	assert_eq(adapter.get_winner(state), "player")
	state = {hp = 0, enemy_hp = 30, turn = 5}
	assert_eq(adapter.get_winner(state), "")


func test_quick_adapter_runs_with_runner() -> void:
	var adapter := _make_combat_adapter()
	var bot := AutoSimRandomBot.new()
	var config := AutoSimConfig.create(adapter, {"player": bot}, 50)
	var report := AutoSimRunner.run(config)
	assert_eq(report.runs.size(), 50)
	gut.p("Quick adapter: %s" % report.summary())


func test_quick_adapter_runs_with_sweep() -> void:
	var adapter := _make_combat_adapter()
	var bot := AutoSimRandomBot.new()
	var result := AutoSimSweepRunner.run(adapter, {"player": bot}, "enemy_hp", [20, 50, 100], 50, 42)
	assert_eq(result.steps.size(), 3)
	gut.p(result.table())


func test_quick_adapter_with_metrics() -> void:
	var adapter := AutoSimQuickAdapter.from({
		setup = func():
			return {hp = 80, enemy_hp = 50, turn = 0},
		actions = func(state: Variant) -> Array:
			return ["attack"] if state["enemy_hp"] > 0 and state["hp"] > 0 else [],
		apply = func(state: Variant, action: Variant) -> Variant:
			state["enemy_hp"] -= 10
			state["hp"] -= 5
			state["turn"] += 1
			return state,
		done = func(state: Variant) -> bool:
			return state["hp"] <= 0 or state["enemy_hp"] <= 0,
		winner = func(state: Variant) -> String:
			return "player" if state["enemy_hp"] <= 0 else "",
		metrics = func(state: Variant) -> Dictionary:
			return {hp_remaining = state["hp"], damage_taken = 80 - state["hp"]},
	})
	var bot := AutoSimRandomBot.new()
	var config := AutoSimConfig.create(adapter, {"player": bot}, 20)
	var report := AutoSimRunner.run(config)
	assert_true(report.runs[0].metrics.has("hp_remaining"), "Should track custom metrics")
	assert_true(report.runs[0].metrics.has("damage_taken"), "Should track custom metrics")


func test_quick_adapter_custom_roles() -> void:
	var adapter := AutoSimQuickAdapter.from({
		roles = ["attacker", "defender"],
		setup = func():
			return {a_hp = 50, d_hp = 50, current = "attacker"},
		actions = func(state: Variant) -> Array:
			return ["strike"],
		current_role = func(state: Variant) -> String:
			return state["current"],
		apply = func(state: Variant, action: Variant) -> Variant:
			if state["current"] == "attacker":
				state["d_hp"] -= 10
				state["current"] = "defender"
			else:
				state["a_hp"] -= 8
				state["current"] = "attacker"
			return state,
		done = func(state: Variant) -> bool:
			return state["a_hp"] <= 0 or state["d_hp"] <= 0,
		winner = func(state: Variant) -> String:
			if state["d_hp"] <= 0: return "attacker"
			if state["a_hp"] <= 0: return "defender"
			return "",
	})
	var roles := adapter.get_roles()
	assert_eq(roles.size(), 2)
	assert_eq(roles[0], "attacker")
