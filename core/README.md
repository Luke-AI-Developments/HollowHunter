# core/

Pure GDScript only. No `Node`, no scene tree, no `_ready()`/`_process()`, no
`get_node()`. Classes here take data in, return data out — nothing else.

Rule: if a script in this folder can't be instantiated and tested with
`GutTest` (see `tests/unit/`) without adding it to a scene, it doesn't belong
here — move it to `scenes/`.

Everything that can be pure lives here: stats, inventory, quest state,
GPS-distance/geofence math, health-data aggregation, save/load serialization.
