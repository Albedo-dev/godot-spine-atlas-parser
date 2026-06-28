extends RefCounted

## Bakes an authored <bundle>.tscn next to the generated .res: a
## PackedAnimatedSprite2D root referencing the .res, with centered=false. For a
## PMA bundle the shared premult_alpha_material is assigned on the root at
## generate-time, so the blend is visible in the inspector with no runtime logic.
## The saved .res and material load as ExtResource references in the packed scene.

const PackedSprite := preload(
	"res://addons/spine_atlas_parser/runtime/packed_animated_sprite_2d.gd"
)
const PREMULT_MATERIAL_PATH := "res://addons/spine_atlas_parser/runtime/premult_alpha_material.tres"
const Result := preload("res://addons/spine_atlas_parser/core/result.gd")


## Writes <output_dir>/<bundle>.tscn. Returns { ok, error, scene_path }.
static func emit(bundle: String, res_path: String, output_dir: String, pma: bool) -> Dictionary:
	var frames: SpriteFrames = load(res_path) as SpriteFrames
	if frames == null:
		return _fail("could not load .res for scene: %s" % res_path)

	var root: AnimatedSprite2D = PackedSprite.new()
	root.name = bundle
	root.centered = false
	root.sprite_frames = frames
	if pma:
		root.material = load(PREMULT_MATERIAL_PATH)

	var scene: PackedScene = PackedScene.new()
	var pack_err: Error = scene.pack(root)
	root.free()
	if pack_err != OK:
		return _fail("PackedScene.pack failed for %s (err %d)" % [bundle, pack_err])

	var scene_path: String = "%s/%s.tscn" % [output_dir, bundle]
	var save_err: Error = ResourceSaver.save(scene, scene_path)
	if save_err != OK:
		return _fail("ResourceSaver failed for %s (err %d)" % [scene_path, save_err])

	return Result.ok({"scene_path": scene_path})


static func _fail(message: String) -> Dictionary:
	push_error("Godot Spine Atlas Parser: " + message)
	return Result.err(message)
