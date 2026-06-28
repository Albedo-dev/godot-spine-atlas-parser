extends RefCounted

## The only pixel mover. Blits each unique source rect into its packed
## placement on a fresh output page Image. Source pages must already be loaded.

static func composite(source_images: Array, unique_list: Array, placements: Dictionary, page_sizes: Array) -> Array:
	var out_pages: Array = []
	for size: Vector2i in page_sizes:
		var img: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		out_pages.append(img)
	for entry: Dictionary in unique_list:
		var placement: Dictionary = placements[entry["key"]]
		var src: Image = source_images[entry["page_idx"]]
		var dst: Image = out_pages[placement["page"]]
		var dst_rect: Rect2i = placement["rect"]
		dst.blit_rect(src, entry["bounds"], dst_rect.position)
	return out_pages
