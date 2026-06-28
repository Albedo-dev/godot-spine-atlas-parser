extends SceneTree

## One-shot helper to (re)generate the committed blue_ooze anchor fixture.
## Reads the real export via SAP_EXPORT_ROOT, generates into a temp user:// dir,
## then copies only the self-contained .res into the fixtures folder. Run when
## the fixture is missing or after flipping PIVOT_Y_BOTTOM_UP (see Plan 2a Task 4).
##
## Run:
##   $env:SAP_EXPORT_ROOT="C:\Users\Ainz\Downloads\Work Related\export_test"
##   <godot> --headless -s res://addons/spine_atlas_parser/tests/fixtures/make_blue_ooze_fixture.gd

const Generator := preload("res://addons/spine_atlas_parser/core/generator.gd")

const FIXTURE_DIR: String = "res://addons/spine_atlas_parser/tests/fixtures/blue_ooze"
const TMP_DIR: String = "user://_blue_ooze_fixture_tmp"
# TMP_DIR is left in place after a run; clean manually from user:// if needed.


func _init() -> void:
	var root: String = OS.get_environment("SAP_EXPORT_ROOT")
	if root == "":
		push_error("SAP_EXPORT_ROOT not set; point it at the export_test folder")
		quit(1)
		return
	var atlas_path: String = root + "/blue_slime/blue_ooze.atlas"
	if not FileAccess.file_exists(atlas_path):
		push_error("blue_ooze.atlas not found at: " + atlas_path)
		quit(1)
		return

	var tmp_err: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP_DIR))
	if tmp_err != OK:
		push_error("failed to create temp dir (err %d): %s" % [tmp_err, TMP_DIR])
		quit(1)
		return
	# efs = null: page texture is embedded in the .res (self-contained fixture).
	var result: Dictionary = Generator.generate_bundle(atlas_path, TMP_DIR, 30, {}, 16384, null)
	if not result["ok"]:
		push_error("generate failed: " + str(result["error"]))
		quit(1)
		return

	var fixture_err: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	if fixture_err != OK:
		push_error("failed to create fixture dir (err %d): %s" % [fixture_err, FIXTURE_DIR])
		quit(1)
		return
	var dst: String = FIXTURE_DIR + "/blue_ooze.res"
	var copy_err: Error = DirAccess.copy_absolute(
		ProjectSettings.globalize_path(result["res_path"]),
		ProjectSettings.globalize_path(dst)
	)
	if copy_err != OK:
		push_error("copy .res failed (err %d)" % copy_err)
		quit(1)
		return

	push_warning("FIXTURE_OK: %s  unique=%d total=%d pages=%d" % [
		dst, result["unique_count"], result["total_frames"], result["page_count"]
	])
	quit(0)
