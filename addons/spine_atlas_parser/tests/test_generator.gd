extends GutTest

const Generator := preload("res://addons/spine_atlas_parser/core/generator.gd")
const Synthetic := preload("res://addons/spine_atlas_parser/tests/fixtures/synthetic.gd")

const TMP_IN: String = "user://sap_test_in"
const TMP_OUT: String = "user://sap_test_out"


func before_each() -> void:
	var d: DirAccess = DirAccess.open("user://")
	d.make_dir_recursive("sap_test_in")
	d.make_dir_recursive("sap_test_out")
	var f: FileAccess = FileAccess.open(TMP_IN + "/hero.atlas", FileAccess.WRITE)
	f.store_string(Synthetic.SAMPLE_ATLAS)
	f.close()
	for page_file: String in Synthetic.PAGE_SIZES:
		var img: Image = Synthetic.build_page_image(page_file)
		img.save_png(TMP_IN + "/" + page_file)


func after_each() -> void:
	_rm_dir(TMP_IN)
	_rm_dir(TMP_OUT)


func _rm_dir(path: String) -> void:
	var d: DirAccess = DirAccess.open(path)
	if d == null:
		return
	# Flat cleanup only - the test dirs hold no subdirectories.
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		d.remove(path + "/" + name)
		name = d.get_next()
	d.list_dir_end()
	var root: DirAccess = DirAccess.open("user://")
	if root != null:
		root.remove(path)


# Write a one-byte stub file, closing the handle deterministically (avoids a
# Windows flake where a dropped FileAccess keeps the dir entry locked).
func _write_stub(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("x")
	f.close()


func test_generates_res_and_png() -> void:
	var result: Dictionary = Generator.generate_bundle(
		TMP_IN + "/hero.atlas", TMP_OUT, 30, {}, 4096, null
	)
	assert_true(result["ok"], "generate ok: " + str(result["error"]))
	assert_true(FileAccess.file_exists(result["res_path"]), ".res written")
	assert_eq(result["png_paths"].size(), 1, "one output page (single page fits)")
	assert_true(FileAccess.file_exists(result["png_paths"][0]), ".png written")


func test_generated_res_loads_with_expected_animations() -> void:
	var result: Dictionary = Generator.generate_bundle(
		TMP_IN + "/hero.atlas", TMP_OUT, 30, {}, 4096, null
	)
	var sf: SpriteFrames = load(result["res_path"]) as SpriteFrames
	assert_not_null(sf, ".res loads as SpriteFrames")
	assert_true(sf.has_animation(&"state_0-walk"), "walk present")
	assert_true(sf.has_animation(&"state_1-death"), "state_1-death present")
	assert_eq(sf.get_frame_count(&"state_0-walk"), 2, "walk 2 frames")
	assert_true(sf.has_meta("pivot_offsets"), "pivot meta present")


func test_dedup_collapses_aliased_frames() -> void:
	var result: Dictionary = Generator.generate_bundle(
		TMP_IN + "/hero.atlas", TMP_OUT, 30, {}, 4096, null
	)
	assert_eq(result["total_frames"], 5, "five region names total")
	assert_eq(result["unique_count"], 4, "dedup leaves four unique rects")


func test_emits_scene_next_to_res() -> void:
	var result: Dictionary = Generator.generate_bundle(
		TMP_IN + "/hero.atlas", TMP_OUT, 30, {}, 4096, null
	)
	assert_true(result["ok"], "generate ok: " + str(result["error"]))
	assert_eq(result["scene_path"], TMP_OUT + "/hero.tscn", "scene path returned")
	assert_true(FileAccess.file_exists(result["scene_path"]), ".tscn written")
	var scene: PackedScene = load(result["scene_path"]) as PackedScene
	var root: AnimatedSprite2D = scene.instantiate()
	assert_not_null(root.sprite_frames, "scene root has sprite_frames")
	assert_null(root.material, "non-PMA scene root has no material")
	root.free()


func test_emit_scene_false_skips_scene() -> void:
	var result: Dictionary = Generator.generate_bundle(
		TMP_IN + "/hero.atlas", TMP_OUT, 30, {}, 4096, null, false
	)
	assert_true(result["ok"], "generate ok: " + str(result["error"]))
	assert_eq(result["scene_path"], "", "no scene path when emit_scene is false")
	assert_false(FileAccess.file_exists(TMP_OUT + "/hero.tscn"), "no .tscn written")
	assert_true(FileAccess.file_exists(result["res_path"]), ".res still written")


# Each entry: relative .atlas path under SAP_EXPORT_ROOT, plus an animation name
# expected in the generated bundle.
const REAL_SAMPLES: Dictionary = {
	"blue_ooze": {"atlas": "blue_slime/blue_ooze.atlas", "anim": "state_0-walk"},
	"dark_matter_slime":
	{"atlas": "dark_matter_slime/DarkMatterSlime.atlas", "anim": "state_0-walk"},
	"wisp_light": {"atlas": "wisp/wisp_light.atlas", "anim": "state_0-walk"},
}


# Generates one real sample end to end and asserts the bundle is sound. Returns
# early as pending when SAP_EXPORT_ROOT (or the sample) is absent.
func _smoke_real_sample(key: String) -> void:
	var root: String = OS.get_environment("SAP_EXPORT_ROOT")
	if root == "":
		pending("set SAP_EXPORT_ROOT to the export_test folder to run the real-sample smoke")
		return
	var sample: Dictionary = REAL_SAMPLES[key]
	var atlas_path: String = root + "/" + sample["atlas"]
	if not FileAccess.file_exists(atlas_path):
		pending(sample["atlas"] + " not found under SAP_EXPORT_ROOT")
		return
	var out_dir: String = "user://sap_real_out_" + key
	DirAccess.open("user://").make_dir_recursive(out_dir.trim_prefix("user://"))
	var result: Dictionary = Generator.generate_bundle(atlas_path, out_dir, 30, {}, 16384, null)
	assert_true(result["ok"], key + " generates: " + str(result["error"]))
	if not result["ok"]:
		return
	var sf: SpriteFrames = load(result["res_path"]) as SpriteFrames
	assert_not_null(sf, key + " .res loads")
	assert_lt(result["unique_count"], result["total_frames"], key + " dedup removed aliased frames")
	assert_true(sf.has_animation(StringName(sample["anim"])), key + " has " + sample["anim"])
	gut.p(
		(
			"%s: %d/%d unique frames, %d output page(s)"
			% [key, result["unique_count"], result["total_frames"], result["png_paths"].size()]
		)
	)


func test_real_blue_ooze_smoke() -> void:
	_smoke_real_sample("blue_ooze")


func test_real_dark_matter_slime_smoke() -> void:
	_smoke_real_sample("dark_matter_slime")


func test_real_wisp_light_smoke() -> void:
	_smoke_real_sample("wisp_light")


func test_generate_bundle_propagates_pma_meta() -> void:
	# Write a tiny PMA atlas + matching 8x8 page, generate, and confirm the
	# built SpriteFrames carries pma=true end-to-end.
	var dir: String = "user://test_pma_bundle"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var atlas_text: String = "p.png\nsize:8,8\nscale:1\npma:true\nmob-state_0-idle_00\nbounds:0,0,4,4\noffsets:0,0,4,4\norigin:2,2\n"
	var atlas_path: String = dir + "/mob.atlas"
	var fa: FileAccess = FileAccess.open(atlas_path, FileAccess.WRITE)
	fa.store_string(atlas_text)
	fa.close()
	var page: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	page.fill(Color(1, 0, 0, 1))
	page.save_png(dir + "/p.png")

	var result: Dictionary = Generator.generate_bundle(atlas_path, dir + "/out", 24, {})
	assert_true(result["ok"], "generate ok: " + str(result["error"]))
	var sf: SpriteFrames = load(result["res_path"]) as SpriteFrames
	assert_not_null(sf, "res loads")
	assert_true(sf.get_meta("pma"), "generated bundle carries pma=true")

	# The emitted scene bakes the premult material onto the root at generate-time.
	var scene: PackedScene = load(result["scene_path"]) as PackedScene
	var root: AnimatedSprite2D = scene.instantiate()
	assert_not_null(root.material, "PMA scene root has the premult material baked")
	assert_eq(
		root.material.resource_path,
		"res://addons/spine_atlas_parser/runtime/premult_alpha_material.tres",
		"baked material is the shared premult resource",
	)
	root.free()

	# cleanup
	_rm_dir(dir + "/out")
	_rm_dir(dir)


func test_scan_bundle_counts_and_base_names() -> void:
	var result: Dictionary = Generator.scan_bundle(TMP_IN + "/hero.atlas")
	assert_true(result["ok"], "scan ok: " + str(result["error"]))
	assert_eq(result["bundle"], "hero", "bundle name is atlas basename")
	assert_eq(result["total_frames"], 5, "five region names")
	assert_eq(result["unique_count"], 4, "dedup leaves four unique rects")
	assert_eq(
		result["base_names"], ["walk", "death", "idle"], "distinct base names, first-seen order"
	)


func test_scan_bundle_missing_atlas_fails() -> void:
	var result: Dictionary = Generator.scan_bundle(TMP_IN + "/nope.atlas")
	assert_false(result["ok"], "missing atlas reports not ok")
	assert_ne(result["error"], "", "error message present")


func test_discover_bundles_finds_one_atlas_per_subfolder() -> void:
	var root: String = "user://sap_discover"
	var d: DirAccess = DirAccess.open("user://")
	d.make_dir_recursive("sap_discover/alpha")
	d.make_dir_recursive("sap_discover/beta")
	d.make_dir_recursive("sap_discover/empty")  # no atlas -> skipped
	_write_stub(root + "/alpha/a.atlas")
	_write_stub(root + "/beta/b.atlas")
	_write_stub(root + "/beta/b.png")  # png ignored
	var found: Array = Generator.discover_bundles(root)
	assert_eq(found.size(), 2, "two subfolders have an atlas")
	assert_true(found[0].ends_with("alpha/a.atlas"), "sorted: alpha first")
	assert_true(found[1].ends_with("beta/b.atlas"), "sorted: beta second")
	# cleanup
	for sub: String in ["alpha", "beta", "empty"]:
		var sd: DirAccess = DirAccess.open(root + "/" + sub)
		if sd != null:
			sd.list_dir_begin()
			var n: String = sd.get_next()
			while n != "":
				sd.remove(root + "/" + sub + "/" + n)
				n = sd.get_next()
			sd.list_dir_end()
		DirAccess.open(root).remove(sub)
	DirAccess.open("user://").remove("sap_discover")
