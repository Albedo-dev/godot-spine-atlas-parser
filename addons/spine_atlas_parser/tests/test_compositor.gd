extends GutTest

const CompositorScript := preload("res://addons/spine_atlas_parser/core/compositor.gd")


func test_blits_rect_to_placement() -> void:
	# One 8x8 source page with a 4x4 red block at (1,1). Place it at (2,2)
	# on a 16x16 output page.
	var src: Image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	src.fill(Color(0, 0, 0, 0))
	src.fill_rect(Rect2i(1, 1, 4, 4), Color(1, 0, 0))
	var unique_list: Array = [{ "key": "k", "page_idx": 0, "bounds": Rect2i(1, 1, 4, 4) }]
	var placements: Dictionary = { "k": { "rect": Rect2i(2, 2, 4, 4), "page": 0 } }
	var page_sizes: Array = [Vector2i(16, 16)]
	var pages: Array = CompositorScript.composite([src], unique_list, placements, page_sizes)
	assert_eq(pages.size(), 1, "one output page")
	var out: Image = pages[0]
	assert_eq(out.get_width(), 16, "output width")
	assert_eq(out.get_pixel(2, 2), Color(1, 0, 0), "pixel blitted to placement")
	assert_eq(out.get_pixel(0, 0).a, 0.0, "background transparent")


func test_routes_to_correct_output_page() -> void:
	var src: Image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	src.fill(Color(0, 0, 0, 0))
	src.fill_rect(Rect2i(0, 0, 2, 2), Color(0, 1, 0))
	var unique_list: Array = [{ "key": "k", "page_idx": 0, "bounds": Rect2i(0, 0, 2, 2) }]
	var placements: Dictionary = { "k": { "rect": Rect2i(0, 0, 2, 2), "page": 1 } }
	var page_sizes: Array = [Vector2i(4, 4), Vector2i(4, 4)]
	var pages: Array = CompositorScript.composite([src], unique_list, placements, page_sizes)
	assert_eq(pages.size(), 2, "two output pages")
	assert_eq(pages[1].get_pixel(0, 0), Color(0, 1, 0), "blitted onto page 1")
