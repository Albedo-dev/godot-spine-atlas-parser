extends GutTest

const PackedSprite := preload(
	"res://addons/spine_atlas_parser/runtime/packed_animated_sprite_2d.gd"
)


## Build a minimal SpriteFrames: one 2x2 frame per named animation, plus the
## pivot_offsets meta keyed by animation name (String keys, as builder.gd writes).
func _frames_with_pivots(pivots: Dictionary) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	for anim_name: String in pivots:
		sf.add_animation(StringName(anim_name))
		sf.add_frame(StringName(anim_name), tex)
	sf.set_meta("pivot_offsets", pivots)
	return sf


func test_centered_false_and_initial_pivot_applied_on_ready() -> void:
	var sf: SpriteFrames = _frames_with_pivots(
		{
			"state_0-walk": Vector2(-10, -20),
			"state_1-idle": Vector2(-5, -5),
		}
	)
	var node: AnimatedSprite2D = PackedSprite.new()
	node.sprite_frames = sf
	node.animation = &"state_0-walk"
	add_child_autofree(node)  # triggers _ready
	assert_false(node.centered, "centered forced false")
	assert_eq(node.offset, Vector2(-10, -20), "initial pivot applied on ready")


func test_pivot_updates_on_animation_change() -> void:
	var sf: SpriteFrames = _frames_with_pivots(
		{
			"state_0-walk": Vector2(-10, -20),
			"state_1-idle": Vector2(-5, -5),
		}
	)
	var node: AnimatedSprite2D = PackedSprite.new()
	node.sprite_frames = sf
	node.animation = &"state_0-walk"
	add_child_autofree(node)
	node.animation = &"state_1-idle"
	assert_eq(node.offset, Vector2(-5, -5), "pivot follows animation_changed")


func test_pivot_refreshes_when_sprite_frames_assigned_after_ready() -> void:
	var node: AnimatedSprite2D = PackedSprite.new()
	add_child_autofree(node)  # _ready with no frames
	var sf: SpriteFrames = _frames_with_pivots({"state_0-walk": Vector2(-7, -8)})
	node.sprite_frames = sf
	node.animation = &"state_0-walk"
	assert_eq(node.offset, Vector2(-7, -8), "pivot read after late sprite_frames assignment")


func test_missing_pivot_meta_defaults_to_zero() -> void:
	var sf: SpriteFrames = SpriteFrames.new()
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	sf.add_animation(&"only")
	sf.add_frame(&"only", ImageTexture.create_from_image(img))
	var node: AnimatedSprite2D = PackedSprite.new()
	node.sprite_frames = sf
	node.animation = &"only"
	add_child_autofree(node)
	assert_eq(node.offset, Vector2.ZERO, "no meta -> zero offset")
