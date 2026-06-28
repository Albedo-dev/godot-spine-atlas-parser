extends RefCounted

## PURE: region list -> animations grouped by "state_<N>-<anim>", frames sorted
## by trailing index. Also returns the base anim name per group (for the loop
## heuristic) and the distinct base names in first-seen order.
##
## Name grammar: "<char>-state_<N>-<anim>_<idx>". State-less names
## ("<char>-<anim>_<idx>") default to state 0. Names without a parseable
## trailing index are kept (idx 0) with a warning. <char> may contain dashes
## (e.g. "mob_2_Tri-Cell"); only the final "-<anim>" segment is the anim.
##
## Frame-index convention: the trailing _<int> is ALWAYS the frame index, per
## the Spine export naming (e.g. death_1, death_2 are frames 1 and 2 of
## "death"). A base anim name that itself ends in _<digits> with no further
## suffix is parsed as (base without the digits, that number as index) -- this
## is intentional and correct for the Spine export convention.

const Result := preload("res://addons/spine_atlas_parser/core/result.gd")

static var _state_re: RegEx
static var _idx_re: RegEx


static func _static_init() -> void:
	_ensure_compiled()


## Compile the static regexes on first use. _static_init does not reliably run
## (or persist) for a preloaded script in the @tool editor context, so callers
## must not assume the static vars are populated; this guard recompiles lazily.
static func _ensure_compiled() -> void:
	if _state_re == null:
		_state_re = RegEx.new()
		_state_re.compile("^.+-state_(\\d+)-(.+)$")
	if _idx_re == null:
		_idx_re = RegEx.new()
		_idx_re.compile("^(.+)_(\\d+)$")


static func group(regions: Array) -> Dictionary:
	_ensure_compiled()
	var animations: Dictionary = {}     # key -> Array[region]
	var anim_base: Dictionary = {}      # key -> base name
	var base_names: Array = []          # distinct base, first-seen order
	var warnings: Array = []
	# Track (key -> Array of [idx, region]) so we can sort after collecting.
	var indexed: Dictionary = {}
	for region: Dictionary in regions:
		var parsed: Dictionary = _parse_name(region["name"])
		if not parsed["has_index"]:
			warnings.append("no parseable frame index in '%s' (treated as 0)" % region["name"])
		var key: String = "state_%d-%s" % [parsed["state"], parsed["anim"]]
		if not indexed.has(key):
			indexed[key] = []
			anim_base[key] = parsed["anim"]
			if not base_names.has(parsed["anim"]):
				base_names.append(parsed["anim"])
		indexed[key].append([parsed["idx"], region])
	for key: String in indexed:
		var pairs: Array = indexed[key]
		pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var frames: Array = []
		for pair: Array in pairs:
			frames.append(pair[1])
		animations[key] = frames
	return Result.ok({
		"warnings": warnings,
		"animations": animations, "anim_base": anim_base, "base_names": base_names
	})


## Returns { state:int, anim:String, idx:int, has_index:bool }.
static func _parse_name(name: String) -> Dictionary:
	var state: int = 0
	var core: String = name
	# Strip "<char>-state_<N>-" prefix if present.
	var m: RegExMatch = _state_re.search(name)
	if m != null:
		state = int(m.get_string(1))
		core = m.get_string(2)
	else:
		# State-less: drop the "<char>-" prefix. Split on the LAST dash so a
		# character name that itself contains dashes (e.g. "mob_2_Tri-Cell")
		# is kept whole and only the trailing "-<anim>_<idx>" remains.
		var dash: int = name.rfind("-")
		if dash >= 0:
			core = name.substr(dash + 1)
	# Trailing _<idx> is always the frame index (Spine export convention).
	var im: RegExMatch = _idx_re.search(core)
	if im != null:
		return { "state": state, "anim": im.get_string(1), "idx": int(im.get_string(2)), "has_index": true }
	return { "state": state, "anim": core, "idx": 0, "has_index": false }
