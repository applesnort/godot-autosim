## Base class for bridging your game to godot-autosim.
##
## Extend this class and implement all methods to expose your game's
## state, actions, and win conditions to the simulation framework.
## The framework treats your game state as opaque — only your adapter
## and your bot strategies need to understand it.
##
## IMPORTANT: Adapters must be stateless during simulation. All game state
## lives in the state Variant passed to each method — do not store mutable
## game state on the adapter instance (self). The same adapter instance is
## reused across runs and sweep steps. Instance properties like enemy_hp
## are configuration, not game state.
class_name AutoSimGameAdapter
extends RefCounted


## Create and return a fresh game state for a new run.
## Called once at the start of each simulation iteration.
func create_initial_state() -> Variant:
	push_error("AutoSimGameAdapter.create_initial_state() not implemented")
	return null


## Return the list of role names (e.g., ["player"] or ["player_1", "player_2"]).
func get_roles() -> Array[String]:
	push_error("AutoSimGameAdapter.get_roles() not implemented")
	return []


## Return whose turn it is (role name).
func get_current_role(state: Variant) -> String:
	push_error("AutoSimGameAdapter.get_current_role() not implemented")
	return ""


## Return available actions for the current role.
## Actions are Variant — the framework passes them to BotStrategy and back
## to apply_action without interpreting them.
func get_available_actions(state: Variant) -> Array:
	push_error("AutoSimGameAdapter.get_available_actions() not implemented")
	return []


## Apply the chosen action to the game state. Return the updated state.
func apply_action(state: Variant, action: Variant) -> Variant:
	push_error("AutoSimGameAdapter.apply_action() not implemented")
	return state


## Return true when the game is over (win, loss, or draw).
func is_game_over(state: Variant) -> bool:
	push_error("AutoSimGameAdapter.is_game_over() not implemented")
	return true


## Return the winning role name, or "" for a draw/loss.
func get_winner(state: Variant) -> String:
	push_error("AutoSimGameAdapter.get_winner() not implemented")
	return ""


## Return any metrics to track for this completed run.
## Keys are metric names (String), values are floats.
## Called once when the game ends.
func get_run_metrics(state: Variant) -> Dictionary:
	return {}


## Called after each run completes. Override to free Nodes or other resources
## that were created in create_initial_state().
func cleanup_state(state: Variant) -> void:
	if state is Node:
		(state as Node).queue_free()
