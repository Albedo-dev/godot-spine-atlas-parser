extends SceneTree

## Verifies the committed blue_ooze fixture loads with pivot metadata and the
## expected animation. Exits non-zero if the fixture is structurally wrong, so
## it doubles as a pass/fail check after (re)generating the fixture.
##
## Run:
##   <godot> --headless -s res://addons/spine_atlas_parser/tests/fixtures/verify_fixture.gd

func _init() -> void:
	var sf: SpriteFrames = load("res://addons/spine_atlas_parser/tests/fixtures/blue_ooze/blue_ooze.res") as SpriteFrames
	if sf == null:
		push_error("fixture did not load as SpriteFrames")
		quit(1)
		return
	if not sf.has_meta("pivot_offsets"):
		push_error("fixture is missing pivot_offsets meta")
		quit(1)
		return
	if not sf.has_animation(&"state_0-walk"):
		push_error("fixture is missing expected animation state_0-walk")
		quit(1)
		return
	push_warning("FIXTURE_OK: anim_count=%d has_pivot_meta=true has_walk=true" % sf.get_animation_names().size())
	quit(0)
