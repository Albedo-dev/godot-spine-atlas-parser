@tool
extends VBoxContainer

## Spine Atlas Parser editor dock. Discovers bundles in a source folder, shows a
## table (Tree) of bundles with per-bundle FPS and per-animation loop child rows,
## and runs Generator.generate_bundle for selected bundles into an output folder.
## Holds no pixel logic and no persistence logic: it orchestrates the core and
## delegates all tool_state.cfg access to ToolState.

const Generator := preload("res://addons/spine_atlas_parser/core/generator.gd")
const C := preload("res://addons/spine_atlas_parser/core/constants.gd")
const ToolState := preload("res://addons/spine_atlas_parser/dock/tool_state.gd")

# Tree columns
const COL_NAME: int = 0  # bundle/anim name + checkbox (Select / Loop)
const COL_FRAMES: int = 1  # "uniq/total"
const COL_FPS: int = 2  # editable range (bundle rows only)
const COL_STATUS: int = 3  # status verb (bundle rows only)
const COL_SCENE: int = 4  # per-bundle authored-scene checkbox (bundle rows only)

var _source_dialog: EditorFileDialog = null
var _output_dialog: EditorFileDialog = null
var _state: ToolState = ToolState.new()

@onready var _tree: Tree = $BundleTree
@onready var _source_path: LineEdit = $SourceRow/SourcePath
@onready var _output_path: LineEdit = $OutputRow/OutputPath
@onready var _status: Label = $StatusLabel
@onready var _progress: ProgressBar = $Progress
@onready var _generate_scenes_check: CheckBox = $Toolbar/GenerateScenesCheck


func _ready() -> void:
	_tree.columns = 5
	_tree.set_column_title(COL_NAME, "Bundle")
	_tree.set_column_title(COL_FRAMES, "Frames")
	_tree.set_column_title(COL_FPS, "FPS")
	_tree.set_column_title(COL_STATUS, "Status")
	_tree.set_column_title(COL_SCENE, "Scene")
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_status.text = "Set source and output folders, then Rescan."
	_source_dialog = _make_dir_dialog(EditorFileDialog.ACCESS_FILESYSTEM)
	_source_dialog.dir_selected.connect(_on_source_selected)
	_output_dialog = _make_dir_dialog(EditorFileDialog.ACCESS_RESOURCES)
	_output_dialog.dir_selected.connect(_on_output_selected)
	$SourceRow/SourceBrowse.pressed.connect(
		func() -> void: _source_dialog.popup_centered_ratio(0.6)
	)
	$OutputRow/OutputBrowse.pressed.connect(
		func() -> void: _output_dialog.popup_centered_ratio(0.6)
	)
	_source_path.text = _state.get_source()
	_output_path.text = _state.get_output()
	$Toolbar/RescanButton.pressed.connect(_on_rescan)
	$Toolbar/SelectAllButton.pressed.connect(func() -> void: _set_all_selected(true))
	$Toolbar/SelectNoneButton.pressed.connect(func() -> void: _set_all_selected(false))
	$Toolbar/GenerateButton.pressed.connect(_on_generate)
	_generate_scenes_check.toggled.connect(_on_generate_scenes_toggled)
	_tree.item_edited.connect(_on_tree_item_edited)


func _make_dir_dialog(access: EditorFileDialog.Access) -> EditorFileDialog:
	var dlg: EditorFileDialog = EditorFileDialog.new()
	dlg.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dlg.access = access
	dlg.title = "Select Folder"
	add_child(dlg)
	return dlg


func _on_source_selected(dir: String) -> void:
	_state.set_source(dir)
	_source_path.text = dir
	_state.save()


func _on_output_selected(dir: String) -> void:
	_state.set_output(dir)
	_output_path.text = dir
	_state.save()


func _on_rescan() -> void:
	_tree.clear()
	var source: String = _state.get_source()
	if source == "":
		_status.text = "Set a source folder first."
		return
	var atlas_paths: Array = Generator.discover_bundles(source)
	if atlas_paths.is_empty():
		_status.text = "No bundles found under %s" % source
		return
	var root: TreeItem = _tree.create_item()
	for atlas_path: String in atlas_paths:
		var scan: Dictionary = Generator.scan_bundle(atlas_path)
		_add_bundle_row(root, atlas_path, scan)
	_status.text = "Found %d bundle(s)." % atlas_paths.size()


func _add_bundle_row(root: TreeItem, atlas_path: String, scan: Dictionary) -> void:
	var item: TreeItem = _tree.create_item(root)
	item.set_metadata(COL_NAME, atlas_path)
	item.set_cell_mode(COL_NAME, TreeItem.CELL_MODE_CHECK)
	item.set_editable(COL_NAME, true)
	item.set_checked(COL_NAME, true)
	if not scan["ok"]:
		item.set_text(COL_NAME, atlas_path.get_file().get_basename())
		item.set_text(COL_STATUS, "Skipped (%s)" % scan["error"])
		return
	item.set_text(COL_NAME, scan["bundle"])
	item.set_text(COL_FRAMES, "%d/%d" % [scan["unique_count"], scan["total_frames"]])
	item.set_cell_mode(COL_FPS, TreeItem.CELL_MODE_RANGE)
	item.set_range_config(COL_FPS, 1, 240, 1)
	item.set_editable(COL_FPS, true)
	item.set_range(COL_FPS, float(_state.get_fps(scan["bundle"])))
	# set_cell_mode resets the cell, so it must precede set_checked.
	item.set_cell_mode(COL_SCENE, TreeItem.CELL_MODE_CHECK)
	item.set_editable(COL_SCENE, true)
	item.set_checked(COL_SCENE, _state.get_generate_scene(scan["bundle"]))
	item.set_text(COL_STATUS, "Ready")
	for base: String in scan["base_names"]:
		var child: TreeItem = _tree.create_item(item)
		# set_cell_mode resets the cell (clears text/checked), so it must come
		# before the label/checked state below or they get wiped.
		child.set_cell_mode(COL_NAME, TreeItem.CELL_MODE_CHECK)
		child.set_editable(COL_NAME, true)
		# The bare base name lives in metadata; the visible text carries the
		# loop/one-shot label so the checkbox's meaning is self-evident.
		child.set_metadata(COL_NAME, base)
		child.set_checked(COL_NAME, _state.get_loop(scan["bundle"], base))
		_apply_loop_label(child)
	item.collapsed = true


func _set_all_selected(value: bool) -> void:
	var root: TreeItem = _tree.get_root()
	if root == null:
		return
	for item: TreeItem in root.get_children():
		item.set_checked(COL_NAME, value)


## Animation-row label: "<base>  (loop)" when checked, "(one-shot)" when not.
## The base name is kept in metadata; this only rewrites the visible text.
func _apply_loop_label(child: TreeItem) -> void:
	var base: String = str(child.get_metadata(COL_NAME))
	var state: String = "loop" if child.is_checked(COL_NAME) else "one-shot"
	child.set_text(COL_NAME, "%s  (%s)" % [base, state])


## Refresh an animation row's loop label live when its checkbox is toggled.
## Bundle rows are children of the hidden root; animation rows are not.
func _on_tree_item_edited() -> void:
	var item: TreeItem = _tree.get_edited()
	if item == null or _tree.get_edited_column() != COL_NAME:
		return
	if item.get_parent() != _tree.get_root():
		_apply_loop_label(item)


## Bulk sweep: set every bundle row's Scene checkbox to the global toggle state.
func _on_generate_scenes_toggled(pressed: bool) -> void:
	var root: TreeItem = _tree.get_root()
	if root == null:
		return
	for item: TreeItem in root.get_children():
		item.set_checked(COL_SCENE, pressed)


func _on_generate() -> void:
	var root: TreeItem = _tree.get_root()
	if root == null:
		_status.text = "Nothing to generate. Rescan first."
		return
	var output: String = _state.get_output()
	if output == "":
		_status.text = "Set an output folder first."
		return
	var bundles: Array = root.get_children()
	var selected: Array = []
	for item: TreeItem in bundles:
		if item.is_checked(COL_NAME):
			selected.append(item)
	if selected.is_empty():
		_status.text = "No bundles selected."
		return
	var efs: Object = EditorInterface.get_resource_filesystem()
	var max_size: int = _max_texture_size()
	_progress.visible = true
	_progress.max_value = selected.size()
	_progress.value = 0
	var ok_count: int = 0
	for item: TreeItem in selected:
		var bundle: String = item.get_text(COL_NAME)
		_status.text = "Generating %s..." % bundle
		var atlas_path: String = item.get_metadata(COL_NAME)
		var fps: int = int(item.get_range(COL_FPS))
		var emit_scene: bool = item.is_checked(COL_SCENE)
		var loop_overrides: Dictionary = {}
		for child: TreeItem in item.get_children():
			loop_overrides[str(child.get_metadata(COL_NAME))] = child.is_checked(COL_NAME)
		var result: Dictionary = Generator.generate_bundle(
			atlas_path, output, fps, loop_overrides, max_size, efs, emit_scene
		)
		if result["ok"]:
			var scene_suffix: String = " + scene" if emit_scene else ""
			item.set_text(
				COL_STATUS, "Generated (%d page(s)%s)" % [result["page_count"], scene_suffix]
			)
			ok_count += 1
		else:
			item.set_text(COL_STATUS, "Skipped (%s)" % result["error"])
		_state.set_fps(bundle, fps)
		_state.set_generate_scene(bundle, emit_scene)
		for base: String in loop_overrides:
			_state.set_loop(bundle, base, loop_overrides[base])
		_progress.value += 1
	_state.save()
	_progress.visible = false
	_status.text = "Generated %d of %d selected bundle(s)." % [ok_count, selected.size()]


## Project/render texture limit; falls back to the named constant when the
## rendering device is unavailable. Never hardcoded (spec section 15).
func _max_texture_size() -> int:
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	if rd != null:
		var limit: int = rd.limit_get(RenderingDevice.LIMIT_MAX_TEXTURE_SIZE_2D)
		if limit > 0:
			return limit
	return C.DEFAULT_MAX_TEXTURE_SIZE
