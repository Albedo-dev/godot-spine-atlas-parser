extends Node2D

## Manual anchor-validation harness (Plan 2a, not shipped). Plays each animation
## of the committed blue_ooze fixture on a PackedAnimatedSprite2D whose origin is
## this node's origin; the crosshair marks that origin. A human confirms the
## pivot lands where expected, resolving PIVOT_Y_BOTTOM_UP (design section 13).
## Left/Right arrows cycle animations.

@export var cross_size: float = 24.0
@export var cross_color: Color = Color(1, 0, 0)

@onready var _sprite: PackedAnimatedSprite2D = $Sprite
@onready var _label: Label = $UI/Label

var _anims: PackedStringArray = []
var _idx: int = 0


func _ready() -> void:
	position = get_viewport_rect().size * 0.5  # center in the default viewport
	if _sprite.sprite_frames != null:
		_anims = _sprite.sprite_frames.get_animation_names()
	_play_current()
	queue_redraw()


func _draw() -> void:
	draw_line(Vector2(-cross_size, 0.0), Vector2(cross_size, 0.0), cross_color, 2.0)
	draw_line(Vector2(0.0, -cross_size), Vector2(0.0, cross_size), cross_color, 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _anims.is_empty():
		return
	if event.keycode == KEY_RIGHT:
		_idx = (_idx + 1) % _anims.size()
		_play_current()
	elif event.keycode == KEY_LEFT:
		_idx = (_idx - 1 + _anims.size()) % _anims.size()
		_play_current()


func _play_current() -> void:
	if _anims.is_empty():
		_label.text = "no animations in fixture"
		return
	var anim_name: String = _anims[_idx]
	_sprite.play(StringName(anim_name))
	_label.text = "%s  (%d/%d)   Left/Right to cycle" % [anim_name, _idx + 1, _anims.size()]
