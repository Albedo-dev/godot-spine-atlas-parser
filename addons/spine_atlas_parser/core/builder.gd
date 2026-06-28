extends RefCounted

## Builds a SpriteFrames from grouped regions + packer placements, and owns the
## trim/pivot math. PIVOT_Y_BOTTOM_UP was validated bottom-up against blue_ooze
## via tests/anchor_check.tscn (design section 13); it is a fixed property of
## Spine's export format, not a per-bundle setting.

const C := preload("res://addons/spine_atlas_parser/core/constants.gd")

const PIVOT_Y_BOTTOM_UP: bool = true


## Godot AtlasTexture.margin restoring the untrimmed frame (top-left origin).
## Spine offsets are bottom-up, so the top trim is orig_h - off_y - h.
static func compute_margin(off_x: int, off_y: int, orig_w: int, orig_h: int, w: int, h: int) -> Rect2:
	return Rect2(off_x, orig_h - off_y - h, orig_w - w, orig_h - h)


## Negated anchor offset (centered = false). origin is in 1x coords; multiply by
## page scale. Y flip per PIVOT_Y_BOTTOM_UP.
static func compute_pivot_offset(origin: Vector2, scale: float, orig_h: int) -> Vector2:
	var pivot_x: float = origin.x * scale
	var pivot_y: float
	if PIVOT_Y_BOTTOM_UP:
		pivot_y = float(orig_h) - origin.y * scale
	else:
		pivot_y = origin.y * scale
	return -Vector2(pivot_x, pivot_y)


## Assemble a SpriteFrames. One animation per "state_N-anim" group; frames are
## AtlasTextures (region = packed placement, margin = compute_margin). Pivot
## offsets (one per anim, origin constant across its frames) go in the
## "pivot_offsets" meta for the runtime sprite to read.
static func build(
	grouped: Dictionary,
	region_key: Dictionary,
	placements: Dictionary,
	page_textures: Array,
	scale: float,
	fps: int,
	loop_overrides: Dictionary,
	pma: bool = false
) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	var pivot_offsets: Dictionary = {}
	var animations: Dictionary = grouped["animations"]
	var anim_base: Dictionary = grouped["anim_base"]
	for anim_name: String in animations:
		var frames: Array = animations[anim_name]
		if frames.is_empty():
			continue
		var key_sn: StringName = StringName(anim_name)
		sf.add_animation(key_sn)
		sf.set_animation_speed(key_sn, float(fps))
		var base: String = anim_base[anim_name]
		var loops: bool = loop_overrides.get(base, C.is_looping_by_default(base))
		sf.set_animation_loop(key_sn, loops)
		for region: Dictionary in frames:
			var key: String = region_key[region["name"]]
			var placement: Dictionary = placements[key]
			var rect: Rect2i = placement["rect"]
			var at: AtlasTexture = AtlasTexture.new()
			at.atlas = page_textures[placement["page"]]
			at.region = Rect2(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
			at.margin = compute_margin(
				region["off_x"], region["off_y"], region["orig_w"], region["orig_h"],
				rect.size.x, rect.size.y
			)
			sf.add_frame(key_sn, at)
		var first: Dictionary = frames[0]
		if OS.is_debug_build():
			for region: Dictionary in frames:
				if region["origin"] != first["origin"]:
					push_warning("builder: origin varies within '%s'; using first frame's origin" % anim_name)
					break
		pivot_offsets[anim_name] = compute_pivot_offset(first["origin"], scale, first["orig_h"])
	sf.set_meta("pivot_offsets", pivot_offsets)
	sf.set_meta("pma", pma)
	return sf
