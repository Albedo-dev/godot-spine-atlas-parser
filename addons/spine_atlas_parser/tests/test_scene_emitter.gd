extends GutTest

## Verifies the generate-time scene baking: emit() writes a <bundle>.tscn whose
## root PackedAnimatedSprite2D references the saved .res and, for PMA bundles,
## carries the shared premult_alpha_material as a baked material (no runtime
## attach). A non-PMA bundle's root has no material.

const SceneEmitter := preload("res://addons/spine_atlas_parser/core/scene_emitter.gd")
const PREMULT_PATH := "res://addons/spine_atlas_parser/runtime/premult_alpha_material.tres"

const TMP_OUT: String = "user://sap_emit_out"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP_OUT))


func after_each() -> void:
	var d: DirAccess = DirAccess.open(TMP_OUT)
	if d == null:
		return
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		d.remove(TMP_OUT + "/" + name)
		name = d.get_next()
	d.list_dir_end()
	DirAccess.open("user://").remove(TMP_OUT.trim_prefix("user://"))


## Save a minimal one-frame SpriteFrames .res to TMP_OUT and return its path.
func _save_frames(bundle: String) -> String:
	var sf: SpriteFrames = SpriteFrames.new()
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	sf.add_frame(&"default", ImageTexture.create_from_image(img))
	var res_path: String = "%s/%s.res" % [TMP_OUT, bundle]
	ResourceSaver.save(sf, res_path)
	return res_path


func test_emit_writes_scene_and_returns_path() -> void:
	var res_path: String = _save_frames("hero")
	var result: Dictionary = SceneEmitter.emit("hero", res_path, TMP_OUT, false)
	assert_true(result["ok"], "emit ok: " + str(result["error"]))
	var scene_path: String = result["scene_path"]
	assert_eq(scene_path, "%s/hero.tscn" % TMP_OUT, "scene path next to the .res")
	assert_true(FileAccess.file_exists(scene_path), ".tscn written to disk")


func test_root_is_packed_sprite_with_frames_wired() -> void:
	var res_path: String = _save_frames("hero")
	var result: Dictionary = SceneEmitter.emit("hero", res_path, TMP_OUT, false)
	var scene: PackedScene = load(result["scene_path"]) as PackedScene
	var root: AnimatedSprite2D = scene.instantiate()
	assert_eq(root.name, &"hero", "root named after the bundle")
	assert_false(root.centered, "centered baked false")
	assert_not_null(root.sprite_frames, "sprite_frames wired")
	assert_eq(root.sprite_frames.resource_path, res_path, "sprite_frames references the saved .res")
	root.free()


func test_pma_bundle_bakes_premult_material() -> void:
	var res_path: String = _save_frames("pma_mob")
	var result: Dictionary = SceneEmitter.emit("pma_mob", res_path, TMP_OUT, true)
	var scene: PackedScene = load(result["scene_path"]) as PackedScene
	var root: AnimatedSprite2D = scene.instantiate()
	assert_not_null(root.material, "PMA bundle bakes a material onto the root")
	assert_eq(root.material.resource_path, PREMULT_PATH, "material is the shared premult resource")
	root.free()


func test_non_pma_bundle_has_no_material() -> void:
	var res_path: String = _save_frames("plain_mob")
	var result: Dictionary = SceneEmitter.emit("plain_mob", res_path, TMP_OUT, false)
	var scene: PackedScene = load(result["scene_path"]) as PackedScene
	var root: AnimatedSprite2D = scene.instantiate()
	assert_null(root.material, "non-PMA bundle bakes no material")
	root.free()
