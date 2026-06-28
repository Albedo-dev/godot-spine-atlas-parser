extends GutTest

const AtlasParser := preload("res://addons/spine_atlas_parser/core/atlas_parser.gd")
const FrameGrouper := preload("res://addons/spine_atlas_parser/core/frame_grouper.gd")
const Synthetic := preload("res://addons/spine_atlas_parser/tests/fixtures/synthetic.gd")


func _regions() -> Array:
	return AtlasParser.parse(Synthetic.SAMPLE_ATLAS)["regions"]


func test_groups_by_state_and_anim() -> void:
	var result: Dictionary = FrameGrouper.group(_regions())
	assert_true(result["ok"], "group ok")
	var anims: Dictionary = result["animations"]
	assert_true(anims.has("state_0-walk"), "state_0-walk present")
	assert_true(anims.has("state_0-death"), "state_0-death present")
	assert_true(anims.has("state_1-death"), "state_1-death present")
	assert_true(anims.has("state_0-idle"), "state_0-idle present")
	assert_eq(anims["state_0-walk"].size(), 2, "walk has 2 frames")
	assert_eq(anims["state_0-death"].size(), 1, "state_0-death has 1 frame")


func test_frames_sorted_by_index() -> void:
	var regions: Array = [
		{ "name": "h-state_0-walk_02", "page_idx": 0, "bounds": Rect2i(), "off_x": 0, "off_y": 0, "orig_w": 1, "orig_h": 1, "origin": Vector2.ZERO },
		{ "name": "h-state_0-walk_00", "page_idx": 0, "bounds": Rect2i(), "off_x": 0, "off_y": 0, "orig_w": 1, "orig_h": 1, "origin": Vector2.ZERO },
		{ "name": "h-state_0-walk_01", "page_idx": 0, "bounds": Rect2i(), "off_x": 0, "off_y": 0, "orig_w": 1, "orig_h": 1, "origin": Vector2.ZERO },
	]
	var result: Dictionary = FrameGrouper.group(regions)
	var frames: Array = result["animations"]["state_0-walk"]
	assert_eq(frames[0]["name"], "h-state_0-walk_00", "first frame idx 0")
	assert_eq(frames[2]["name"], "h-state_0-walk_02", "last frame idx 2")


func test_base_names_and_anim_base() -> void:
	var result: Dictionary = FrameGrouper.group(_regions())
	assert_eq(result["anim_base"]["state_1-death"], "death", "anim_base maps to base name")
	assert_eq(result["base_names"], ["walk", "death", "idle"], "distinct base names")


func test_stateless_name_defaults_to_state_0() -> void:
	var regions: Array = [
		{ "name": "Peeker-idle_00", "page_idx": 0, "bounds": Rect2i(), "off_x": 0, "off_y": 0, "orig_w": 1, "orig_h": 1, "origin": Vector2.ZERO },
	]
	var result: Dictionary = FrameGrouper.group(regions)
	assert_true(result["animations"].has("state_0-idle"), "stateless name -> state_0-idle")


func test_unparseable_index_warns() -> void:
	var regions: Array = [
		{ "name": "h-state_0-spin", "page_idx": 0, "bounds": Rect2i(), "off_x": 0, "off_y": 0, "orig_w": 1, "orig_h": 1, "origin": Vector2.ZERO },
	]
	var result: Dictionary = FrameGrouper.group(regions)
	assert_true(result["ok"], "still groups")
	assert_gt(result["warnings"].size(), 0, "emits a warning for the missing index")


## Pin: trailing _<int> is always the frame index even when the anim base itself
## contains _<digits>. hero-state_0-attack_2_03 -> anim "attack_2", idx 3.
func test_multi_underscore_trailing_index_pinned() -> void:
	var regions: Array = [
		{ "name": "hero-state_0-attack_2_03", "page_idx": 0, "bounds": Rect2i(), "off_x": 0, "off_y": 0, "orig_w": 1, "orig_h": 1, "origin": Vector2.ZERO },
	]
	var result: Dictionary = FrameGrouper.group(regions)
	assert_true(result["ok"], "group ok")
	assert_true(result["animations"].has("state_0-attack_2"), "key is state_0-attack_2")
	var frames: Array = result["animations"]["state_0-attack_2"]
	assert_eq(frames.size(), 1, "one frame")
	assert_eq(frames[0]["name"], "hero-state_0-attack_2_03", "correct region")
	assert_eq(result["anim_base"]["state_0-attack_2"], "attack_2", "base is attack_2")


## Pin: a state-less character name containing dashes (e.g. "mob_2_Tri-Cell")
## keeps the char whole and yields just the final anim. mob_2_Tri-Cell-attack_00
## -> anim "attack", state 0.
func test_stateless_dashed_character_name() -> void:
	var regions: Array = [
		{ "name": "mob_2_Tri-Cell-attack_00", "page_idx": 0, "bounds": Rect2i(), "off_x": 0, "off_y": 0, "orig_w": 1, "orig_h": 1, "origin": Vector2.ZERO },
		{ "name": "mob_2_Tri-Cell-attack_01", "page_idx": 0, "bounds": Rect2i(), "off_x": 0, "off_y": 0, "orig_w": 1, "orig_h": 1, "origin": Vector2.ZERO },
	]
	var result: Dictionary = FrameGrouper.group(regions)
	assert_true(result["ok"], "group ok")
	assert_true(result["animations"].has("state_0-attack"), "key is state_0-attack")
	assert_eq(result["animations"]["state_0-attack"].size(), 2, "attack has 2 frames")
	assert_eq(result["anim_base"]["state_0-attack"], "attack", "base is attack")


## Reproduces the editor @tool context where the static RegEx vars are null
## (Godot does not reliably run _static_init for a preloaded script there).
## group() must compile them on demand rather than crash.
func test_group_works_when_static_regex_state_missing() -> void:
	FrameGrouper._state_re = null
	FrameGrouper._idx_re = null
	var regions: Array = [
		{ "name": "hero-state_0-walk_00" },
		{ "name": "hero-state_1-death_02" },
	]
	var result: Dictionary = FrameGrouper.group(regions)
	assert_true(result["ok"], "group succeeds with regex state missing")
	assert_true(result["animations"].has("state_0-walk"), "walk grouped")
	assert_true(result["animations"].has("state_1-death"), "death grouped")
