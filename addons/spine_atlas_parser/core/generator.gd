extends RefCounted

## Orchestrates one bundle end-to-end: .atlas + page PNGs -> SpriteFrames .res
## (+ re-packed page PNG). Pure modules do the work; this wires them together
## and handles disk I/O. Pass `efs` (an EditorFileSystem) for the imported-
## texture path; null embeds an ImageTexture (headless). `efs` is typed Object
## because EditorFileSystem is not available as a type in headless runs; its
## methods are invoked via call().

const C := preload("res://addons/spine_atlas_parser/core/constants.gd")
const AtlasParser := preload("res://addons/spine_atlas_parser/core/atlas_parser.gd")
const FrameGrouper := preload("res://addons/spine_atlas_parser/core/frame_grouper.gd")
const Packer := preload("res://addons/spine_atlas_parser/core/packer.gd")
const CompositorScript := preload("res://addons/spine_atlas_parser/core/compositor.gd")
const Builder := preload("res://addons/spine_atlas_parser/core/builder.gd")
const SceneEmitter := preload("res://addons/spine_atlas_parser/core/scene_emitter.gd")
const Result := preload("res://addons/spine_atlas_parser/core/result.gd")


## Dedup key for a source rect: page index + bounds. Single source of the
## format (test_builder._prep mirrors it; keep them in sync).
static func dedup_key(page_idx: int, bounds: Rect2i) -> String:
	return (
		"%d:%d,%d,%d,%d"
		% [page_idx, bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]
	)


## Walks regions once, building the dedup structures keyed by (page_idx, bounds).
## Shared by generate_bundle (needs all three) and scan_bundle (needs the counts).
static func _dedup(regions: Array) -> Dictionary:
	var region_key: Dictionary = {}  # region name -> dedup key
	var unique: Dictionary = {}  # key -> { key, size }
	var unique_list: Array = []  # ordered: { key, page_idx, bounds }
	for region: Dictionary in regions:
		var b: Rect2i = region["bounds"]
		var key: String = dedup_key(region["page_idx"], b)
		region_key[region["name"]] = key
		if not unique.has(key):
			unique[key] = {"key": key, "size": b.size}
			unique_list.append({"key": key, "page_idx": region["page_idx"], "bounds": b})
	return {"region_key": region_key, "unique": unique, "unique_list": unique_list}


## Shared front half of the pipeline (validate, read, parse, group, dedup) for
## both scan and generate. Returns Result.err on failure, or a success dict with
## the bundle name and the parsed/grouped/dedup structures. Does NOT push_error;
## callers surface the failure as they need (scan passes it through, generate
## re-wraps via _fail).
static func _load_and_analyze(atlas_path: String) -> Dictionary:
	if not FileAccess.file_exists(atlas_path):
		return Result.err("atlas not found: %s" % atlas_path)
	var text: String = FileAccess.get_file_as_string(atlas_path)
	var parsed: Dictionary = AtlasParser.parse(text)
	if not parsed["ok"]:
		return Result.err("parse failed: %s" % parsed["error"])
	var grouped: Dictionary = FrameGrouper.group(parsed["regions"])
	if not grouped["ok"]:
		return Result.err("grouping failed: %s" % grouped["error"])
	var dd: Dictionary = _dedup(parsed["regions"])
	return Result.ok(
		{
			"bundle": atlas_path.get_file().get_basename(),
			"parsed": parsed,
			"grouped": grouped,
			"dd": dd
		}
	)


## Read-only inspection for the dock: parse + group + dedup, no compositing or
## save. Returns counts and the distinct animation base names for the table.
static func scan_bundle(atlas_path: String) -> Dictionary:
	var analyzed: Dictionary = _load_and_analyze(atlas_path)
	if not analyzed["ok"]:
		return analyzed
	var parsed: Dictionary = analyzed["parsed"]
	var dd: Dictionary = analyzed["dd"]
	return Result.ok(
		{
			"bundle": analyzed["bundle"],
			"total_frames": parsed["regions"].size(),
			"unique_count": dd["unique"].size(),
			"base_names": analyzed["grouped"]["base_names"]
		}
	)


## Returns the sorted list of `<source>/<subfolder>/<name>.atlas` paths, one per
## immediate subfolder that contains at least one .atlas (first .atlas wins).
## Subfolders without an .atlas are skipped.
static func discover_bundles(source_dir: String) -> Array:
	var found: Array = []
	var root: DirAccess = DirAccess.open(source_dir)
	if root == null:
		return found
	root.list_dir_begin()
	var entry: String = root.get_next()
	var subfolders: Array = []
	while entry != "":
		if entry != "." and entry != ".." and root.current_is_dir():
			subfolders.append(entry)
		entry = root.get_next()
	root.list_dir_end()
	subfolders.sort()
	for sub: String in subfolders:
		var sub_path: String = source_dir + "/" + sub
		var sd: DirAccess = DirAccess.open(sub_path)
		if sd == null:
			continue
		var atlases: Array = []
		sd.list_dir_begin()
		var f: String = sd.get_next()
		while f != "":
			if not sd.current_is_dir() and f.get_extension() == "atlas":
				atlases.append(f)
			f = sd.get_next()
		sd.list_dir_end()
		if not atlases.is_empty():
			atlases.sort()
			found.append(sub_path + "/" + atlases[0])
	return found


static func generate_bundle(
	atlas_path: String,
	output_dir: String,
	fps: int,
	loop_overrides: Dictionary,
	max_size: int = C.DEFAULT_MAX_TEXTURE_SIZE,
	efs: Object = null,
	emit_scene: bool = true
) -> Dictionary:
	var analyzed: Dictionary = _load_and_analyze(atlas_path)
	if not analyzed["ok"]:
		return _fail(analyzed["error"])
	var bundle: String = analyzed["bundle"]
	var page_dir: String = atlas_path.get_base_dir()
	var parsed: Dictionary = analyzed["parsed"]
	var grouped: Dictionary = analyzed["grouped"]

	var dd: Dictionary = analyzed["dd"]
	var region_key: Dictionary = dd["region_key"]
	var unique: Dictionary = dd["unique"]
	var unique_list: Array = dd["unique_list"]

	var packed: Dictionary = Packer.pack(unique.values(), max_size)
	if not packed["ok"]:
		return _fail("packing failed: %s" % packed["error"])

	var source_images: Array = []
	for page: Dictionary in parsed["pages"]:
		var src_path: String = page_dir + "/" + page["file"]
		var img: Image = Image.load_from_file(src_path)
		if img == null:
			return _fail("missing/unreadable page: %s" % src_path)
		source_images.append(img)

	var out_images: Array = CompositorScript.composite(
		source_images, unique_list, packed["placements"], packed["page_sizes"]
	)

	# globalize_path resolves user:// and res:// to a real OS path for mkdir.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var png_paths: Array = []
	var page_textures: Array = []
	for p: int in range(out_images.size()):
		var suffix: String = "" if p == 0 else "_%d" % (p + 1)
		var png_path: String = "%s/%s%s.png" % [output_dir, bundle, suffix]
		# save_png accepts user:// / res:// paths directly (no globalize needed here).
		var save_err: Error = out_images[p].save_png(png_path)
		if save_err != OK:
			return _fail("save_png failed for %s (err %d)" % [png_path, save_err])
		png_paths.append(png_path)
		page_textures.append(_resolve_texture(png_path, out_images[p], efs))

	# Spine emits one uniform scale + pma per export; page 0's values apply to all.
	var scale: float = parsed["pages"][0]["scale"]
	var pma: bool = parsed["pages"][0]["pma"]
	var sf: SpriteFrames = Builder.build(
		grouped, region_key, packed["placements"], page_textures, scale, fps, loop_overrides, pma
	)

	var res_path: String = "%s/%s.res" % [output_dir, bundle]
	var res_err: Error = ResourceSaver.save(sf, res_path, ResourceSaver.FLAG_COMPRESS)
	if res_err != OK:
		return _fail("ResourceSaver failed for %s (err %d)" % [res_path, res_err])

	# Bake an authored scene only when requested (root references this .res; PMA
	# bakes the material). The .res is the product; the scene is convenience.
	var scene_path: String = ""
	if emit_scene:
		var emitted: Dictionary = SceneEmitter.emit(bundle, res_path, output_dir, pma)
		if not emitted["ok"]:
			return _fail(emitted["error"])
		scene_path = emitted["scene_path"]

	return Result.ok(
		{
			"res_path": res_path,
			"png_paths": png_paths,
			"scene_path": scene_path,
			"unique_count": unique.size(),
			"total_frames": parsed["regions"].size(),
			"page_count": out_images.size()
		}
	)


## Editor path: import the PNG and reference it (ext resource). Headless path:
## embed an ImageTexture built from the composed image. efs is Object (an
## EditorFileSystem when in the editor); its methods are called dynamically.
static func _resolve_texture(png_path: String, image: Image, efs: Object) -> Texture2D:
	if efs != null:
		efs.call("update_file", png_path)
		efs.call("reimport_files", PackedStringArray([png_path]))
		var imported: Texture2D = load(png_path) as Texture2D
		if imported != null:
			return imported
		push_warning(
			(
				"Godot Spine Atlas Parser: import not ready for %s; embedding ImageTexture instead"
				% png_path
			)
		)
	return ImageTexture.create_from_image(image)


static func _fail(message: String) -> Dictionary:
	push_error("Godot Spine Atlas Parser: " + message)
	return Result.err(message)
