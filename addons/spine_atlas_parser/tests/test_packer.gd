extends GutTest

const Packer := preload("res://addons/spine_atlas_parser/core/packer.gd")


func test_empty_input() -> void:
	var result: Dictionary = Packer.pack([], 1000)
	assert_true(result["ok"], "empty packs ok")
	assert_eq(result["placements"].size(), 0, "no placements")
	assert_eq(result["page_sizes"].size(), 0, "no pages")


func test_deterministic_two_item_layout() -> void:
	var items: Array = [
		{ "key": "a", "size": Vector2i(10, 20) },
		{ "key": "b", "size": Vector2i(10, 10) },
	]
	var result: Dictionary = Packer.pack(items, 1000)
	assert_true(result["ok"], "packs ok")
	# wrap_width = max(14, ceil(sqrt(264+144)=20.2)=21) = 21. b wraps to a 2nd shelf.
	assert_eq(result["placements"]["a"]["rect"], Rect2i(2, 2, 10, 20), "a at (2,2)")
	assert_eq(result["placements"]["a"]["page"], 0, "a on page 0")
	assert_eq(result["placements"]["b"]["rect"], Rect2i(2, 24, 10, 10), "b on 2nd shelf")
	assert_eq(result["page_sizes"], [Vector2i(14, 36)], "page trimmed to content")


func test_all_items_placed_without_overlap() -> void:
	var items: Array = []
	for k: int in range(12):
		items.append({ "key": "k%d" % k, "size": Vector2i(7 + (k % 3) * 4, 5 + (k % 4) * 3) })
	var result: Dictionary = Packer.pack(items, 1000)
	assert_true(result["ok"], "packs ok")
	assert_eq(result["placements"].size(), 12, "every item placed exactly once")
	var rects: Array = []
	for key: String in result["placements"]:
		var p: Dictionary = result["placements"][key]
		var r: Rect2i = p["rect"]
		var page: int = p["page"]
		var page_size: Vector2i = result["page_sizes"][page]
		assert_true(r.position.x >= 0 and r.position.y >= 0, "%s in-bounds origin" % key)
		assert_true(r.end.x <= page_size.x and r.end.y <= page_size.y, "%s within page" % key)
		rects.append([page, r])
	for i: int in range(rects.size()):
		for j: int in range(i + 1, rects.size()):
			if rects[i][0] == rects[j][0]:
				assert_false(rects[i][1].intersects(rects[j][1]), "rects %d/%d disjoint" % [i, j])


func test_single_frame_over_budget_errors() -> void:
	var result: Dictionary = Packer.pack([{ "key": "big", "size": Vector2i(30, 5) }], 20)
	assert_false(result["ok"], "oversize single frame rejected")


func test_spills_to_second_page() -> void:
	# Two 10x10 frames with max_size 20: the second cannot fit a new shelf
	# vertically, so it spills onto page 1.
	var items: Array = [
		{ "key": "a", "size": Vector2i(10, 10) },
		{ "key": "b", "size": Vector2i(10, 10) },
	]
	var result: Dictionary = Packer.pack(items, 20)
	assert_true(result["ok"], "packs ok")
	assert_eq(result["page_sizes"].size(), 2, "spilled to two pages")
	assert_eq(result["placements"]["a"]["page"], 0, "a on page 0")
	assert_eq(result["placements"]["b"]["page"], 1, "b on page 1")
