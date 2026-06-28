extends RefCounted

## Shared result envelope for the pipeline. `ok(payload)` tags a success dict and
## merges the payload; `err(message)` is the minimal failure ({ok:false, error}).
## Failures carry no payload keys on purpose: every caller guards on `ok` before
## reading payload, so zeroed placeholders were dead weight. Pure, no I/O.


static func ok(payload: Dictionary = {}) -> Dictionary:
	var r: Dictionary = {"ok": true, "error": ""}
	r.merge(payload)  # overwrite=false: payload cannot clobber ok/error
	return r


static func err(message: String) -> Dictionary:
	return {"ok": false, "error": message}
