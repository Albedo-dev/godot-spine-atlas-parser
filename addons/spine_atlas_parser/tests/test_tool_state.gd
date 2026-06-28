extends GutTest

const ToolState := preload("res://addons/spine_atlas_parser/dock/tool_state.gd")
const C := preload("res://addons/spine_atlas_parser/core/constants.gd")

const SCRATCH: String = "user://_test_tool_state.cfg"


func before_each() -> void:
	_delete_scratch()


func after_each() -> void:
	_delete_scratch()


func _delete_scratch() -> void:
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))


func test_defaults_when_no_file() -> void:
	var st: RefCounted = ToolState.new(SCRATCH)
	assert_eq(st.get_source(), "", "source defaults empty")
	assert_eq(st.get_output(), "", "output defaults empty")
	assert_eq(st.get_fps("any_bundle"), C.DEFAULT_FPS, "fps defaults to DEFAULT_FPS")
	assert_true(st.get_loop("b", "walk"), "walk loops by default")
	assert_false(st.get_loop("b", "death"), "death is one-shot by default")


func test_round_trips_through_save() -> void:
	var st: RefCounted = ToolState.new(SCRATCH)
	st.set_source("res://src")
	st.set_output("res://out")
	st.set_fps("blue_ooze", 24)
	st.set_loop("blue_ooze", "death", true)
	assert_eq(st.save(), OK, "save succeeds")

	var reloaded: RefCounted = ToolState.new(SCRATCH)
	assert_eq(reloaded.get_source(), "res://src", "source persists")
	assert_eq(reloaded.get_output(), "res://out", "output persists")
	assert_eq(reloaded.get_fps("blue_ooze"), 24, "fps persists")
	assert_true(reloaded.get_loop("blue_ooze", "death"), "loop override persists")


func test_loop_is_keyed_per_bundle() -> void:
	var st: RefCounted = ToolState.new(SCRATCH)
	st.set_loop("b1", "walk", false)
	st.set_loop("b2", "walk", true)
	assert_false(st.get_loop("b1", "walk"), "b1 walk override")
	assert_true(st.get_loop("b2", "walk"), "b2 walk independent of b1")


func test_fps_is_keyed_per_bundle() -> void:
	var st: RefCounted = ToolState.new(SCRATCH)
	st.set_fps("b1", 12)
	assert_eq(st.get_fps("b1"), 12, "b1 fps set")
	assert_eq(st.get_fps("b2"), C.DEFAULT_FPS, "b2 fps still default")


func test_generate_scene_defaults_true() -> void:
	var st: RefCounted = ToolState.new(SCRATCH)
	assert_true(st.get_generate_scene("any_bundle"), "generate_scene defaults true")


func test_generate_scene_round_trips_per_bundle() -> void:
	var st: RefCounted = ToolState.new(SCRATCH)
	st.set_generate_scene("b1", false)
	assert_eq(st.save(), OK, "save succeeds")
	var reloaded: RefCounted = ToolState.new(SCRATCH)
	assert_false(reloaded.get_generate_scene("b1"), "b1 false persists")
	assert_true(reloaded.get_generate_scene("b2"), "b2 still default true")
