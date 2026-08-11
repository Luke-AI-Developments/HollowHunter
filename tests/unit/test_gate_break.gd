extends GutTest
## GateBreak: trigger probability + reward multiplier (§8b). See
## core/gate_break.gd for why the trigger/reward numbers are invented and
## why there's no real push notification here.


func test_should_trigger_never_fires_before_cooldown_elapses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# last_offer_unix 1 second ago, cooldown is hours -- must never fire
	# regardless of roll or hour, so try many rolls/hours.
	for h in range(0, 24):
		assert_false(GateBreak.should_trigger(1000, 999, h, rng))


func test_should_trigger_can_fire_once_cooldown_elapses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var now := 100000
	var last_offer := now - GateBreak.MIN_INTERVAL_SECONDS
	# Roll many times at a guaranteed-past-cooldown gap; base chance is
	# > 0 so this must fire at least once across enough rolls.
	var fired := false
	for i in 200:
		if GateBreak.should_trigger(now, last_offer, 12, rng):
			fired = true
			break
	assert_true(fired)


func test_should_trigger_never_offered_before_has_no_cooldown_gate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# last_offer_unix == 0 means "never offered" -- cooldown doesn't apply.
	var fired := false
	for i in 200:
		if GateBreak.should_trigger(1000, 0, 12, rng):
			fired = true
			break
	assert_true(fired)


func test_should_trigger_weights_evening_hours_higher() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 5
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 5
	var now := 100000
	var last_offer := now - GateBreak.MIN_INTERVAL_SECONDS

	var day_fires := 0
	for i in 500:
		if GateBreak.should_trigger(now, last_offer, 10, rng_a):
			day_fires += 1
	var evening_fires := 0
	for i in 500:
		if GateBreak.should_trigger(now, last_offer, 20, rng_b):
			evening_fires += 1

	assert_true(evening_fires > day_fires)


func test_bonus_essence_scales_above_the_base_amount() -> void:
	assert_true(GateBreak.bonus_essence(100) > 100)


func test_bonus_essence_is_the_documented_multiplier() -> void:
	assert_eq(GateBreak.bonus_essence(200), int(round(200 * GateBreak.BREAK_REWARD_MULTIPLIER)))
