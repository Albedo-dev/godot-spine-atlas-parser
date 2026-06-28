extends RefCounted

## PURE: Spine 4.2+ compact `.atlas` text -> { ok, error, pages[], regions[] }.
## No Godot UI, no Image. Format: `key:value` (no space after colon), region
## attributes not indented, blank line between pages. Rotation is rejected;
## PMA (pma:true) is accepted and recorded on the page as `pma: bool`.

const Result := preload("res://addons/spine_atlas_parser/core/result.gd")


static func parse(text: String) -> Dictionary:
	var pages: Array = []
	var regions: Array = []
	var lines: PackedStringArray = text.split("\n")
	var n: int = lines.size()
	var i: int = 0
	while i < n:
		# Skip blank lines between pages.
		while i < n and lines[i].strip_edges() == "":
			i += 1
		if i >= n:
			break
		# --- page header (filename) ---
		var page_file: String = lines[i].strip_edges()
		i += 1
		var page: Dictionary = {
			"file": page_file, "size": Vector2i.ZERO, "scale": 1.0,
			"filter": "", "pma": false
		}
		var page_idx: int = pages.size()
		# --- page properties (colon lines) until the first colon-less line ---
		while i < n:
			var s: String = lines[i].strip_edges()
			if s == "" or not s.contains(":"):
				break
			var err: String = _apply_page_key(page, s)
			if err != "":
				return Result.err(err)
			i += 1
		pages.append(page)
		# --- regions until a blank line (end of page) ---
		while i < n:
			var rs: String = lines[i].strip_edges()
			if rs == "":
				i += 1
				break
			if rs.contains(":"):
				return Result.err("unexpected property before a region name: '%s'" % rs)
			# region name line
			var region: Dictionary = {
				"name": rs, "page_idx": page_idx, "bounds": Rect2i(),
				"off_x": 0, "off_y": 0, "orig_w": 0, "orig_h": 0, "origin": Vector2.ZERO
			}
			i += 1
			while i < n:
				var attr_line: String = lines[i].strip_edges()
				if attr_line == "" or not attr_line.contains(":"):
					break
				var rerr: String = _apply_region_key(region, attr_line)
				if rerr != "":
					return Result.err(rerr)
				i += 1
			# Untrimmed regions omit `offsets:`, leaving orig size unset; default it
			# to the bounds size so the builder restores the full frame instead of
			# collapsing the AtlasTexture to 0x0 (negative margin).
			if region["orig_w"] == 0 and region["orig_h"] == 0:
				region["orig_w"] = region["bounds"].size.x
				region["orig_h"] = region["bounds"].size.y
			regions.append(region)
	return Result.ok({"pages": pages, "regions": regions})


static func _apply_page_key(page: Dictionary, line: String) -> String:
	var key: String = line.get_slice(":", 0).strip_edges()
	var val: String = line.substr(line.find(":") + 1).strip_edges()
	match key:
		"size":
			var p: PackedStringArray = val.split(",")
			if p.size() < 2:
				return "malformed size value: '%s'" % val
			page["size"] = Vector2i(int(p[0]), int(p[1]))
		"scale":
			page["scale"] = float(val)
		"filter":
			page["filter"] = val
		"pma":
			page["pma"] = (val.to_lower() == "true")
		"format", "repeat":
			pass
		_:
			pass  # tolerate unknown page keys
	return ""


static func _apply_region_key(region: Dictionary, line: String) -> String:
	var key: String = line.get_slice(":", 0).strip_edges()
	var val: String = line.substr(line.find(":") + 1).strip_edges()
	match key:
		"bounds":
			var b: PackedStringArray = val.split(",")
			if b.size() < 4:
				return "malformed bounds value: '%s'" % val
			region["bounds"] = Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3]))
		"offsets":
			var o: PackedStringArray = val.split(",")
			if o.size() < 4:
				return "malformed offsets value: '%s'" % val
			region["off_x"] = int(o[0])
			region["off_y"] = int(o[1])
			region["orig_w"] = int(o[2])
			region["orig_h"] = int(o[3])
		"origin":
			var g: PackedStringArray = val.split(",")
			if g.size() < 2:
				return "malformed origin value: '%s'" % val
			region["origin"] = Vector2(float(g[0]), float(g[1]))
		"rotate":
			return "rotation is not supported; disable rotation in the Spine atlas export"
		"index":
			pass
		_:
			pass  # tolerate unknown region keys
	return ""
