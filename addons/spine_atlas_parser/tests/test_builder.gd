extends GutTest

const Builder := preload("res://addons/spine_atlas_parser/core/builder.gd")
const AtlasParser := preload("res://addons/spine_atlas_parser/core/atlas_parser.gd")
const FrameGrouper := preload("res://addons/spine_atlas_parser/core/frame_grouper.gd")
const Generator := preload("res://addons/spine_atlas_parser/core/generator.gd")
const Packer := preload("res://addons/spine_atlas_parser/core/packer.gd")
const Synthetic := preload("res://addons/spine_atlas_parser/tests/fixtures/synthetic.gd")


func test_compute_margin_worked_example() -> void:
	# blue_ooze-state_0-walk_06: bounds w=269 h=280, offsets 8,0,282,280.
	var margin: Rect2 = Builder.compute_margin(8, 0, 282, 280, 269, 280)
	assert_eq(margin, Rect2(8, 0, 13, 0), "margin matches spec worked example")
	# Final logical size = region + margin = (282, 280) = (orig_w, orig_h).
	assert_eq(Vector2(269, 280) + margin.size, Vector2(282, 280), "restores logical frame size")


func test_compute_margin_synthetic() -> void:
	# walk_00: offsets 2,3,24,24 ; bounds w=20 h=20.
	var margin: Rect2 = Builder.compute_margin(2, 3, 24, 24, 20, 20)
	assert_eq(margin, Rect2(2, 1, 4, 4), "synthetic margin")


func test_compute_pivot_offset_bottom_up() -> void:
	# origin (580,541), scale 0.25, orig_h 280. Bottom-up (hypothesis).
	var offset: Vector2 = Builder.compute_pivot_offset(Vector2(580, 541), 0.25, 280)
	assert_almost_eq(offset.x, -145.0, 0.01, "pivot x = -(580*0.25)")
	assert_almost_eq(offset.y, -144.75, 0.01, "pivot y = -(280 - 541*0.25) bottom-up")


# Builds the inputs builder.build needs from the synthetic fixture.
func _prep() -> Dictionary:
	var parsed: Dictionary = AtlasParser.parse(Synthetic.SAMPLE_ATLAS)
	var grouped: Dictionary = FrameGrouper.group(parsed["regions"])
	var region_key: Dictionary = {}
	var unique: Dictionary = {}   # key -> {key,size}
	for region: Dictionary in parsed["regions"]:
		var b: Rect2i = region["bounds"]
		var key: String = Generator.dedup_key(region["page_idx"], b)
		region_key[region["name"]] = key
		if not unique.has(key):
			unique[key] = { "key": key, "size": b.size }
	var packed: Dictionary = Packer.pack(unique.values(), 4096)
	var textures: Array = []
	for size: Vector2i in packed["page_sizes"]:
		var img: Image = Image.create_empty(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
		textures.append(ImageTexture.create_from_image(img))
	return { "grouped": grouped, "region_key": region_key, "placements": packed["placements"], "textures": textures }


func test_build_sprite_frames_animations() -> void:
	var p: Dictionary = _prep()
	var sf: SpriteFrames = Builder.build(p["grouped"], p["region_key"], p["placements"], p["textures"], 0.5, 24, {})
	assert_false(sf.has_animation(&"default"), "default animation removed")
	assert_true(sf.has_animation(&"state_0-walk"), "walk animation present")
	assert_eq(sf.get_frame_count(&"state_0-walk"), 2, "walk has 2 frames")
	assert_eq(sf.get_animation_speed(&"state_0-walk"), 24.0, "fps applied")


func test_build_loop_heuristic_and_override() -> void:
	var p: Dictionary = _prep()
	var sf: SpriteFrames = Builder.build(p["grouped"], p["region_key"], p["placements"], p["textures"], 0.5, 30, {})
	assert_true(sf.get_animation_loop(&"state_0-walk"), "walk loops by default")
	assert_false(sf.get_animation_loop(&"state_0-death"), "death does not loop by default")
	var sf2: SpriteFrames = Builder.build(p["grouped"], p["region_key"], p["placements"], p["textures"], 0.5, 30, { "death": true })
	assert_true(sf2.get_animation_loop(&"state_0-death"), "death override forces loop on")


func test_build_atlas_texture_region_and_pivot_meta() -> void:
	var p: Dictionary = _prep()
	var sf: SpriteFrames = Builder.build(p["grouped"], p["region_key"], p["placements"], p["textures"], 0.5, 30, {})
	var tex: AtlasTexture = sf.get_frame_texture(&"state_0-death", 0) as AtlasTexture
	assert_not_null(tex, "death frame 0 is an AtlasTexture")
	assert_eq(tex.margin, Rect2(0, 0, 0, 0), "death margin zero (untrimmed)")
	var pivots: Dictionary = sf.get_meta("pivot_offsets")
	assert_true(pivots.has("state_0-walk"), "pivot meta present per anim")
	assert_almost_eq(pivots["state_0-walk"].x, -24.0, 0.01, "walk pivot x")
	assert_almost_eq(pivots["state_0-walk"].y, -4.0, 0.01, "walk pivot y")


func test_build_pma_meta_defaults_false() -> void:
	var p: Dictionary = _prep()
	var sf: SpriteFrames = Builder.build(p["grouped"], p["region_key"], p["placements"], p["textures"], 0.5, 24, {})
	assert_true(sf.has_meta("pma"), "pma meta always written")
	assert_false(sf.get_meta("pma"), "pma meta defaults false")


func test_build_pma_meta_true_when_passed() -> void:
	var p: Dictionary = _prep()
	var sf: SpriteFrames = Builder.build(p["grouped"], p["region_key"], p["placements"], p["textures"], 0.5, 24, {}, true)
	assert_true(sf.get_meta("pma"), "pma meta true when build called with pma=true")
