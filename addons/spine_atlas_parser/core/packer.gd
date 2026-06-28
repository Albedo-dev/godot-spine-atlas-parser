extends RefCounted

## PURE: shelf-pack unique rects into one (or, on spill, more) output pages.
## Input items: [{ "key": String, "size": Vector2i }]. PADDING is the gap/border
## between frames. See the plan's Task 5 header for the locked algorithm.

const C := preload("res://addons/spine_atlas_parser/core/constants.gd")
const Result := preload("res://addons/spine_atlas_parser/core/result.gd")


static func pack(items: Array, max_size: int) -> Dictionary:
	if items.is_empty():
		return Result.ok({"placements": {}, "page_sizes": []})
	var pad: int = C.PADDING
	var total_area: int = 0
	var max_item_w: int = 0
	for item: Dictionary in items:
		var sz: Vector2i = item["size"]
		if sz.x + 2 * pad > max_size or sz.y + 2 * pad > max_size:
			return Result.err("frame %s (%dx%d) exceeds the texture budget %d" % [item["key"], sz.x, sz.y, max_size])
		total_area += (sz.x + pad) * (sz.y + pad)
		max_item_w = maxi(max_item_w, sz.x)
	var sorted: Array = items.duplicate()
	sorted.sort_custom(_compare)
	var wrap_width: int = clampi(int(ceil(sqrt(float(total_area)))), max_item_w + 2 * pad, max_size)
	var placements: Dictionary = {}
	var page: int = 0
	var cursor_x: int = pad
	var cursor_y: int = pad
	var shelf_h: int = 0
	for item: Dictionary in sorted:
		var sz: Vector2i = item["size"]
		if cursor_x > pad and cursor_x + sz.x + pad > wrap_width:
			cursor_x = pad
			cursor_y += shelf_h + pad
			shelf_h = 0
		if cursor_y + sz.y + pad > max_size:
			page += 1
			cursor_x = pad
			cursor_y = pad
			shelf_h = 0
		placements[item["key"]] = { "rect": Rect2i(cursor_x, cursor_y, sz.x, sz.y), "page": page }
		cursor_x += sz.x + pad
		shelf_h = maxi(shelf_h, sz.y)
	var page_count: int = page + 1
	var page_sizes: Array = []
	for p: int in range(page_count):
		var w: int = 0
		var h: int = 0
		for key: String in placements:
			if placements[key]["page"] != p:
				continue
			var r: Rect2i = placements[key]["rect"]
			w = maxi(w, r.end.x + pad)
			h = maxi(h, r.end.y + pad)
		page_sizes.append(Vector2i(w, h))
	return Result.ok({"placements": placements, "page_sizes": page_sizes})


static func _compare(a: Dictionary, b: Dictionary) -> bool:
	var sa: Vector2i = a["size"]
	var sb: Vector2i = b["size"]
	if sa.y != sb.y:
		return sa.y > sb.y
	if sa.x != sb.x:
		return sa.x > sb.x
	return String(a["key"]) < String(b["key"])
