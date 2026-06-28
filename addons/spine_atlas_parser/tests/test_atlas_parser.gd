extends GutTest

const AtlasParser := preload("res://addons/spine_atlas_parser/core/atlas_parser.gd")
const Synthetic := preload("res://addons/spine_atlas_parser/tests/fixtures/synthetic.gd")


func test_parses_two_pages() -> void:
	var result: Dictionary = AtlasParser.parse(Synthetic.SAMPLE_ATLAS)
	assert_true(result["ok"], "parse succeeds: " + str(result["error"]))
	assert_eq(result["pages"].size(), 2, "two pages parsed")


func test_page_header_fields() -> void:
	var result: Dictionary = AtlasParser.parse(Synthetic.SAMPLE_ATLAS)
	var page0: Dictionary = result["pages"][0]
	assert_eq(page0["file"], "page1.png", "page 0 filename")
	assert_eq(page0["size"], Vector2i(64, 64), "page 0 size")
	assert_almost_eq(page0["scale"], 0.5, 0.0001, "page 0 scale")
	assert_eq(result["pages"][1]["file"], "page2.png", "page 1 filename")


func test_region_count_and_page_idx() -> void:
	var result: Dictionary = AtlasParser.parse(Synthetic.SAMPLE_ATLAS)
	assert_eq(result["regions"].size(), 5, "five regions parsed")
	var idle: Dictionary = result["regions"].back()
	assert_eq(idle["name"], "hero-state_0-idle_00", "last region name")
	assert_eq(idle["page_idx"], 1, "idle region is on page index 1")


func test_region_fields() -> void:
	var result: Dictionary = AtlasParser.parse(Synthetic.SAMPLE_ATLAS)
	var walk0: Dictionary = result["regions"][0]
	assert_eq(walk0["bounds"], Rect2i(0, 0, 20, 20), "walk_00 bounds")
	assert_eq(walk0["off_x"], 2, "walk_00 off_x")
	assert_eq(walk0["off_y"], 3, "walk_00 off_y")
	assert_eq(walk0["orig_w"], 24, "walk_00 orig_w")
	assert_eq(walk0["orig_h"], 24, "walk_00 orig_h")
	assert_eq(walk0["origin"], Vector2(48, 40), "walk_00 origin")


func test_untrimmed_region_defaults_orig_to_bounds() -> void:
	# Untrimmed frames omit the offsets: line. orig_w/orig_h must default to the
	# bounds size (not stay 0), or builder.compute_margin gets a negative margin
	# and the AtlasTexture collapses to 0x0 (blank frame).
	var text: String = "p.png\nsize:256,256\nscale:1\nr-state_0-walk_00\nbounds:0,0,200,152\norigin:100,76\n"
	var result: Dictionary = AtlasParser.parse(text)
	assert_true(result["ok"], "no-offsets region parses: " + str(result["error"]))
	var region: Dictionary = result["regions"][0]
	assert_eq(region["orig_w"], 200, "orig_w defaults to bounds width")
	assert_eq(region["orig_h"], 152, "orig_h defaults to bounds height")
	assert_eq(region["off_x"], 0, "off_x stays 0 for untrimmed")
	assert_eq(region["off_y"], 0, "off_y stays 0 for untrimmed")


func test_malformed_page_size_too_few_values() -> void:
	var atlas: String = "page1.png\nsize:64\nfilter:Linear,Linear\n"
	var result: Dictionary = AtlasParser.parse(atlas)
	assert_false(result["ok"], "malformed size: should fail")


func test_malformed_bounds_too_few_values() -> void:
	var atlas: String = "page1.png\nsize:64,64\nregion_a\nbounds:0,0,20\n"
	var result: Dictionary = AtlasParser.parse(atlas)
	assert_false(result["ok"], "malformed bounds: should fail")


func test_malformed_offsets_too_few_values() -> void:
	var atlas: String = "page1.png\nsize:64,64\nregion_a\nbounds:0,0,20,20\noffsets:2,3\n"
	var result: Dictionary = AtlasParser.parse(atlas)
	assert_false(result["ok"], "malformed offsets: should fail")


func test_malformed_origin_too_few_values() -> void:
	var atlas: String = "page1.png\nsize:64,64\nregion_a\nbounds:0,0,20,20\norigin:48\n"
	var result: Dictionary = AtlasParser.parse(atlas)
	assert_false(result["ok"], "malformed origin: should fail")


func test_rejects_rotation() -> void:
	var text: String = "p.png\nsize:8,8\nscale:1\nr-state_0-x_00\nbounds:0,0,4,4\nrotate:90\noffsets:0,0,4,4\norigin:2,2\n"
	var result: Dictionary = AtlasParser.parse(text)
	assert_false(result["ok"], "rotation rejected")
	assert_string_contains(result["error"], "rotation", "error mentions rotation")


func test_accepts_pma() -> void:
	var text: String = "p.png\nsize:8,8\nscale:1\npma:true\nr-state_0-x_00\nbounds:0,0,4,4\noffsets:0,0,4,4\norigin:2,2\n"
	var result: Dictionary = AtlasParser.parse(text)
	assert_true(result["ok"], "pma:true now accepted: " + str(result["error"]))
	assert_true(result["pages"][0]["pma"], "page records pma true")


func test_pma_defaults_false_when_absent() -> void:
	var text: String = "p.png\nsize:8,8\nscale:1\nr-state_0-x_00\nbounds:0,0,4,4\noffsets:0,0,4,4\norigin:2,2\n"
	var result: Dictionary = AtlasParser.parse(text)
	assert_true(result["ok"], "no pma key still parses")
	assert_false(result["pages"][0]["pma"], "pma defaults false when key absent")


func test_scale_variants() -> void:
	var text: String = "p.png\nsize:8,8\nscale:0.175\nr-state_0-x_00\nbounds:0,0,4,4\noffsets:0,0,4,4\norigin:2,2\n"
	var result: Dictionary = AtlasParser.parse(text)
	assert_true(result["ok"], "0.175 scale parses")
	assert_almost_eq(result["pages"][0]["scale"], 0.175, 0.0001, "scale 0.175")


func test_handles_trailing_crlf() -> void:
	# Real files may use CRLF; strip_edges() must absorb the \r.
	var text: String = "p.png\r\nsize:8,8\r\nscale:1\r\nr-state_0-x_00\r\nbounds:0,0,4,4\r\noffsets:0,0,4,4\r\norigin:2,2\r\n"
	var result: Dictionary = AtlasParser.parse(text)
	assert_true(result["ok"], "CRLF parses")
	assert_eq(result["regions"].size(), 1, "one region despite CRLF")
