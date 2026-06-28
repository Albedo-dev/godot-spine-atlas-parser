extends GutTest

const C := preload("res://addons/spine_atlas_parser/core/constants.gd")


func test_gut_harness_runs() -> void:
	assert_eq(1, 1, "GUT harness executes a trivial assertion")


func test_constants_loaded() -> void:
	assert_eq(C.PADDING, 2, "PADDING constant is 2")
	assert_eq(C.DEFAULT_FPS, 30, "DEFAULT_FPS constant is 30")


func test_loop_heuristic() -> void:
	assert_false(C.is_looping_by_default("death"), "death does not loop by default")
	assert_false(C.is_looping_by_default("Hit"), "case-insensitive non-looping match")
	assert_true(C.is_looping_by_default("walk"), "walk loops by default")
