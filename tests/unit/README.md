# tests/unit/

GUT tests, one file per `core/` class: `core/inventory.gd` -> `tests/unit/test_inventory.gd`.
Every `core/` script needs a matching test file. Nothing native/platform
(GPS, Health Connect) is unit tested here — that's exercised on-device.
