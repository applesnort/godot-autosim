## Lambda-based adapter — define your game with functions instead of a class.
##
## Usage:
##   var adapter = AutoSimQuickAdapter.from({
##       setup = func(): return {hp = 80, enemy_hp = 50},
##       actions = func(state): return ["attack", "defend"],
##       apply = func(state, action): state.enemy_hp -= 10; return state,
##       done = func(state): return state.hp <= 0 or state.enemy_hp <= 0,
##       winner = func(state): return "player" if state.enemy_hp <= 0 else "",
##   })
##
## Optional keys:
##   roles        — Array[String], default ["player"]
##   current_role — Callable(state) -> String, default returns roles[0]
##   metrics      — Callable(state) -> Dictionary, default returns {}
##
## The "enemy_hp" property (or any property you add) is accessible for sweeps
## via the built-in property forwarding.
class_name AutoSimQuickAdapter
extends AutoSimGameAdapter

var _setup: Callable
var _actions: Callable
var _apply: Callable
var _done: Callable
var _winner: Callable
var _metrics: Callable
var _roles: Array[String]
var _current_role: Callable

## Swept properties — set() forwards here so sweeps work.
var _swept_props: Dictionary = {}


static func from(config: Dictionary) -> AutoSimQuickAdapter:
	var adapter := AutoSimQuickAdapter.new()
	adapter._setup = config["setup"]
	adapter._actions = config["actions"]
	adapter._apply = config["apply"]
	adapter._done = config["done"]
	adapter._winner = config["winner"]

	var roles_input: Array = config.get("roles", ["player"])
	for r in roles_input:
		adapter._roles.append(String(r))
	var cr: Variant = config.get("current_role", Callable())
	if cr is Callable:
		adapter._current_role = cr
	var m: Variant = config.get("metrics", Callable())
	if m is Callable:
		adapter._metrics = m

	# Extract initial state to find sweepable properties
	var initial_state: Variant = adapter._setup.call()
	if initial_state is Dictionary:
		for key in initial_state:
			adapter._swept_props[key] = initial_state[key]

	return adapter


func create_initial_state() -> Variant:
	var state: Variant = _setup.call()
	# Apply any swept property overrides
	if state is Dictionary:
		for key in _swept_props:
			if state.has(key):
				state[key] = _swept_props[key]
	return state


func get_roles() -> Array[String]:
	return _roles


func get_current_role(state: Variant) -> String:
	if _current_role.is_valid():
		return _current_role.call(state)
	return _roles[0]


func get_available_actions(state: Variant) -> Array:
	return _actions.call(state)


func apply_action(state: Variant, action: Variant) -> Variant:
	return _apply.call(state, action)


func is_game_over(state: Variant) -> bool:
	return _done.call(state)


func get_winner(state: Variant) -> String:
	return _winner.call(state)


func get_run_metrics(state: Variant) -> Dictionary:
	if _metrics.is_valid():
		return _metrics.call(state)
	return {}


func _set(property: StringName, value: Variant) -> bool:
	var key := String(property)
	if _swept_props.has(key):
		_swept_props[key] = value
		return true
	return false


func _get(property: StringName) -> Variant:
	var key := String(property)
	if _swept_props.has(key):
		return _swept_props[key]
	return null


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	for key in _swept_props:
		props.append({
			name = key,
			type = typeof(_swept_props[key]),
			usage = PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	return props
