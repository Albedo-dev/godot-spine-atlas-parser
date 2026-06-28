extends RefCounted

## Shared named constants for the Godot Spine Atlas Parser pipeline.
## Referenced via `const C := preload("res://addons/spine_atlas_parser/core/constants.gd")`.

const PADDING: int = 2                       # px gap/border between packed frames (linear-filter bleed guard)
const DEFAULT_FPS: int = 30
const NON_LOOPING_NAMES: Array[String] = ["death", "hit", "spawn"]
const DEFAULT_MAX_TEXTURE_SIZE: int = 16384  # fallback; the dock passes the project/render limit in Plan 2


## Loop default for an animation base name (dock pre-fills the same heuristic).
static func is_looping_by_default(base_name: String) -> bool:
	return not NON_LOOPING_NAMES.has(base_name.to_lower())
