# autoload/

Godot autoload singletons. Thin wrappers only -- each one calls into a pure
`core/` class for the actual logic and does nothing itself but the engine
call the pure class can't make (file I/O, plugin singleton access, etc.).
Not unit tested for the same reason `scenes/` isn't: the logic they wrap
already is.
