class_name ShopView
extends Node2D
## Phase 4/shop step 1: the item shop (§14/§26) as its own thin view
## script -- same split-out-of-main.gd reasoning as battle_view.gd/
## squad_view.gd (main.gd was already near the project's max-file-lines
## lint limit). Owns display + input forwarding only; scenes/main.gd owns
## the actual purchase rules (affordability, what each purchase grants)
## and calls refresh() with data it already computed.
##
## Unlike SquadView's positional rows (squad membership reshuffles at
## runtime), the shop catalog is static content -- rows are built once
## from it via setup(), keyed by id/kind instead of by slot index.

signal buy_ticket_bundle_requested(id: String)
signal buy_essence_bundle_requested(id: String)
signal buy_cosmetic_requested(id: String)
signal close_requested

var _catalog: Dictionary = {}
var _rows: Array = []  ## Array[Dictionary]: {label, buy_btn, id, kind}

@onready var crystals_label: Label = $CrystalsLabel
@onready var rows_container: Node2D = $Rows


func _ready() -> void:
	$CloseButton.pressed.connect(func() -> void: close_requested.emit())


## Builds the fixed row list from the catalog -- call once, after
## Content.load_shop(). Row order: ticket bundles, then Essence bundles,
## then cosmetics, in each section's own content order.
func setup(catalog: Dictionary) -> void:
	_catalog = catalog
	var y := 0.0
	for bundle: Dictionary in _catalog.get("ticket_bundles", []):
		_rows.append(_build_row(y, String(bundle["id"]), "ticket"))
		y += 50
	for bundle: Dictionary in _catalog.get("essence_bundles", []):
		_rows.append(_build_row(y, String(bundle["id"]), "essence"))
		y += 50
	for cosmetic: Dictionary in _catalog.get("cosmetics", []):
		_rows.append(_build_row(y, String(cosmetic["id"]), "cosmetic"))
		y += 50


func _build_row(y: float, id: String, kind: String) -> Dictionary:
	var row_label := Label.new()
	row_label.position = Vector2(40, y)
	row_label.size = Vector2(720, 40)
	row_label.add_theme_font_size_override("font_size", 20)
	rows_container.add_child(row_label)

	var buy_btn := Button.new()
	buy_btn.position = Vector2(780, y)
	buy_btn.size = Vector2(220, 40)
	buy_btn.text = "Buy"
	rows_container.add_child(buy_btn)
	buy_btn.pressed.connect(_on_row_buy_pressed.bind(id, kind))

	return {"label": row_label, "buy_btn": buy_btn, "id": id, "kind": kind}


func _on_row_buy_pressed(id: String, kind: String) -> void:
	match kind:
		"ticket":
			buy_ticket_bundle_requested.emit(id)
		"essence":
			buy_essence_bundle_requested.emit(id)
		"cosmetic":
			buy_cosmetic_requested.emit(id)


func refresh(crystals: int, owned_cosmetics: Array) -> void:
	crystals_label.text = "Crystals: %d" % crystals
	for row: Dictionary in _rows:
		match String(row["kind"]):
			"ticket":
				_refresh_ticket_row(row, crystals)
			"essence":
				_refresh_essence_row(row, crystals)
			"cosmetic":
				_refresh_cosmetic_row(row, crystals, owned_cosmetics)


func _refresh_ticket_row(row: Dictionary, crystals: int) -> void:
	var bundle := Content.shop_item_by_id(_catalog["ticket_bundles"], row["id"])
	var cost := int(bundle.get("crystal_cost", 0))
	row["label"].text = "%d Gate Ticket(s) -- %d Crystals" % [bundle.get("tickets", 0), cost]
	row["buy_btn"].text = "Buy"
	row["buy_btn"].disabled = crystals < cost


func _refresh_essence_row(row: Dictionary, crystals: int) -> void:
	var bundle := Content.shop_item_by_id(_catalog["essence_bundles"], row["id"])
	var cost := int(bundle.get("crystal_cost", 0))
	row["label"].text = "%d Essence -- %d Crystals" % [bundle.get("essence", 0), cost]
	row["buy_btn"].text = "Buy"
	row["buy_btn"].disabled = crystals < cost


func _refresh_cosmetic_row(row: Dictionary, crystals: int, owned_cosmetics: Array) -> void:
	var cosmetic := Content.shop_item_by_id(_catalog["cosmetics"], row["id"])
	var cost := int(cosmetic.get("crystal_cost", 0))
	var owned := owned_cosmetics.has(row["id"])
	row["label"].text = (
		"%s -- %d Crystals%s" % [cosmetic.get("name", ""), cost, " (owned)" if owned else ""]
	)
	row["buy_btn"].text = "Owned" if owned else "Buy"
	row["buy_btn"].disabled = owned or crystals < cost
