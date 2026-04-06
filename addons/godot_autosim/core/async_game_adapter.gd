## Base class for games with async/coroutine game loops.
##
## Use this instead of AutoSimGameAdapter when your game's action methods
## contain `await` statements (e.g., for animation delays that are guarded
## by `if visual_delays`). The framework handles the coroutine plumbing.
##
## The adapter methods are identical to AutoSimGameAdapter except:
## - apply_action_async() replaces apply_action()
## - You must `await` game methods inside it
class_name AutoSimAsyncGameAdapter
extends AutoSimGameAdapter


## Async version of apply_action. Use `await` freely inside.
## The framework awaits this method for each bot action.
func apply_action_async(state: Variant, action: Variant) -> Variant:
	push_error("AutoSimAsyncGameAdapter.apply_action_async() not implemented")
	return state
