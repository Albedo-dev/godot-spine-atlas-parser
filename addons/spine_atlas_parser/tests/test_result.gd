extends GutTest

const Result := preload("res://addons/spine_atlas_parser/core/result.gd")


func test_ok_tags_success_and_merges_payload() -> void:
	var r: Dictionary = Result.ok({"regions": [1, 2], "count": 2})
	assert_true(r["ok"], "ok flag true")
	assert_eq(r["error"], "", "error empty on success")
	assert_eq(r["regions"], [1, 2], "payload merged")
	assert_eq(r["count"], 2, "payload merged")


func test_ok_with_no_payload() -> void:
	var r: Dictionary = Result.ok()
	assert_true(r["ok"], "ok flag true")
	assert_eq(r["error"], "", "error empty")
	assert_eq(r.size(), 2, "no stray keys")


func test_err_is_minimal() -> void:
	var r: Dictionary = Result.err("boom")
	assert_false(r["ok"], "ok flag false")
	assert_eq(r["error"], "boom", "error carries message")
	assert_eq(r.size(), 2, "err carries no payload keys")


func test_payload_cannot_clobber_ok_flag() -> void:
	# A stray ok/error in the payload must not override the success tag.
	var r: Dictionary = Result.ok({"ok": false, "error": "nope"})
	assert_true(r["ok"], "ok stays true")
	assert_eq(r["error"], "", "error stays empty")
