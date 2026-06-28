# Godot Spine Atlas Parser

A Godot 4 editor addon that turns a Spine **packed** export (atlas pages plus
its `.atlas` sidecar) into anchored `SpriteFrames` bundles. A lightweight
`AnimatedSprite2D`-based alternative to a full Spine runtime for simple enemies.

Requires Godot 4.4 or newer.

## Enable

Enable the plugin in Project Settings > Plugins, then open the **Spine Atlas
Parser** dock.

## Spine export settings

- Pack: ON (packed atlas export).
- Rotation: OFF (rotated regions are rejected).
- Premultiply alpha: either; both straight and PMA exports are supported.
- Frame naming: `state_<N>-<animation>` (the `state_<N>-` prefix is optional,
  defaults to `0`).

## Workflow

1. In the dock, pick the source export folder and an output folder in your
   project.
2. Scan, then set FPS and whether to emit a scene. Loop vs one-shot is
   auto-detected per animation by name (`death`, `hit`, `spawn` default to
   one-shot, all others loop); override any with its checkbox.
3. Generate Selected to produce a `<bundle>.res` (and optional `<bundle>.tscn`).

Use a bundle by instancing the generated `<bundle>.tscn`, or by adding a
`PackedAnimatedSprite2D` and assigning the `<bundle>.res` to `sprite_frames`.
Play animations by name, for example `play("state_0-walk")`.

## Premultiplied alpha

The generated scene already bakes `premult_alpha_material.tres` onto a PMA
bundle's root. If you assign the `.res` to your own node, set its `material` to
`res://addons/spine_atlas_parser/runtime/premult_alpha_material.tres` for a PMA
bundle (the runtime node does not auto-apply it).

## License

MIT. See [LICENSE.md](LICENSE.md).
