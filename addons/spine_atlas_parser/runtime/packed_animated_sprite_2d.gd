@tool
class_name PackedAnimatedSprite2D
extends AnimatedSprite2D

## Drop-in replacement for SpineSprite on packed-atlas enemies. Applies the
## per-animation pivot offset baked into the SpriteFrames "pivot_offsets" meta
## (see builder.gd) so the node origin (0,0) sits on Spine's origin. centered is
## forced false. Anchoring uses signals rather than overriding play(), which a
## statically-typed call cannot intercept from GDScript, and the node is @tool
## so the offset also applies live in the editor when a bundle is hand-wired in.
## PMA blending is baked at generate-time (scene_emitter assigns the premult
## material on the emitted <bundle>.tscn root); this node carries no material
## logic. Registered globally via class_name, independent of any plugin.

const PIVOT_META: StringName = &"pivot_offsets"

var _pivot_offsets: Dictionary = {}


func _ready() -> void:
	centered = false
	_refresh_pivots()
	if not sprite_frames_changed.is_connected(_on_sprite_frames_changed):
		sprite_frames_changed.connect(_on_sprite_frames_changed)
	if not animation_changed.is_connected(_on_animation_changed):
		animation_changed.connect(_on_animation_changed)
	_apply_pivot()


func _on_sprite_frames_changed() -> void:
	_refresh_pivots()
	_apply_pivot()


func _on_animation_changed() -> void:
	_apply_pivot()


## Pull the pivot table from the frames meta; empty if absent.
func _refresh_pivots() -> void:
	if sprite_frames != null and sprite_frames.has_meta(PIVOT_META):
		_pivot_offsets = (sprite_frames.get_meta(PIVOT_META) as Dictionary).duplicate()
	else:
		_pivot_offsets = {}


## offset = stored per-animation pivot (already negated by builder) or ZERO.
func _apply_pivot() -> void:
	offset = _pivot_offsets.get(animation, Vector2.ZERO)
