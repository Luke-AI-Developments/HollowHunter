# scenes/

`.tscn` files and their attached view scripts. A view script wires a `core/`
class to nodes — signals, `_ready()`, UI updates — and stays thin. No game
rules here; if you catch yourself writing an `if` that decides game outcome
rather than display, that logic belongs in `core/`.
