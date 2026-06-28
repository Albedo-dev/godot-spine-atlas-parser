extends RefCounted

## Owns the dock's persisted state in `tool_state.cfg`: source/output folders,
## per-bundle FPS, and per-animation loop flags. The held ConfigFile is loaded on
## construction and IS the source of truth; mutations write into it and `save()`
## flushes the whole model. The path is injectable so tests use a scratch file.
## A single owner means no load-before-save dance and one home for the key format.
## FPS/loop defaults defer to constants.gd so callers never re-derive them.

const C := preload("res://addons/spine_atlas_parser/core/constants.gd")

const DEFAULT_PATH: String = "res://addons/spine_atlas_parser/tool_state.cfg"

const _PATHS: String = "paths"
const _FPS: String = "fps"
const _LOOP: String = "loop"
const _SCENE: String = "scene"

var _cfg: ConfigFile = ConfigFile.new()
var _path: String = DEFAULT_PATH


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	_cfg.load(_path)  # absent file leaves an empty model, which is correct


func get_source() -> String:
	return str(_cfg.get_value(_PATHS, "source", ""))


func set_source(dir: String) -> void:
	_cfg.set_value(_PATHS, "source", dir)


func get_output() -> String:
	return str(_cfg.get_value(_PATHS, "output", ""))


func set_output(dir: String) -> void:
	_cfg.set_value(_PATHS, "output", dir)


func get_fps(bundle: String) -> int:
	return int(_cfg.get_value(_FPS, bundle, C.DEFAULT_FPS))


func set_fps(bundle: String, fps: int) -> void:
	_cfg.set_value(_FPS, bundle, fps)


## Stored loop flag for an animation, falling back to the name heuristic.
func get_loop(bundle: String, base: String) -> bool:
	return bool(_cfg.get_value(_LOOP, _loop_key(bundle, base), C.is_looping_by_default(base)))


func set_loop(bundle: String, base: String, loops: bool) -> void:
	_cfg.set_value(_LOOP, _loop_key(bundle, base), loops)


## Per-bundle authored-scene emission flag, defaulting on.
func get_generate_scene(bundle: String) -> bool:
	return bool(_cfg.get_value(_SCENE, bundle, true))


func set_generate_scene(bundle: String, value: bool) -> void:
	_cfg.set_value(_SCENE, bundle, value)


func save() -> Error:
	return _cfg.save(_path)


## Per-bundle namespacing for loop keys; the one place this format is defined.
func _loop_key(bundle: String, base: String) -> String:
	return "%s/%s" % [bundle, base]
