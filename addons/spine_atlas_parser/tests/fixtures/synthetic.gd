extends RefCounted

## Shared synthetic Spine packed export for the pipeline tests.
## Grammar matches the real samples: `key:value`, no space after the colon,
## region attributes not indented, blank line between pages.

const SAMPLE_ATLAS: String = """page1.png
size:64,64
filter:Linear,Linear
scale:0.5
hero-state_0-walk_00
bounds:0,0,20,20
offsets:2,3,24,24
origin:48,40
hero-state_0-walk_01
bounds:22,0,20,20
offsets:2,3,24,24
origin:48,40
hero-state_0-death_00
bounds:0,22,16,16
offsets:0,0,16,16
origin:32,32
hero-state_1-death_00
bounds:0,22,16,16
offsets:0,0,16,16
origin:32,32

page2.png
size:32,32
filter:Linear,Linear
scale:0.5
hero-state_0-idle_00
bounds:0,0,10,10
offsets:0,0,10,10
origin:20,20
"""

## Page sizes keyed by filename, for building matching test images.
const PAGE_SIZES: Dictionary = {
	"page1.png": Vector2i(64, 64),
	"page2.png": Vector2i(32, 32),
}

## Bounds painted on each page (for compositor/generator pixel checks),
## as { page_file: [ { "rect": Rect2i, "color": Color } ] }.
const PAGE_FILLS: Dictionary = {
	"page1.png": [
		{ "rect": Rect2i(0, 0, 20, 20), "color": Color(1, 0, 0) },
		{ "rect": Rect2i(22, 0, 20, 20), "color": Color(0, 1, 0) },
		{ "rect": Rect2i(0, 22, 16, 16), "color": Color(0, 0, 1) },
	],
	"page2.png": [
		{ "rect": Rect2i(0, 0, 10, 10), "color": Color(1, 1, 0) },
	],
}


## Build a page Image filled transparent with the known rects painted solid.
static func build_page_image(page_file: String) -> Image:
	var size: Vector2i = PAGE_SIZES[page_file]
	var img: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for fill: Dictionary in PAGE_FILLS[page_file]:
		var rect: Rect2i = fill["rect"]
		img.fill_rect(rect, fill["color"])
	return img
