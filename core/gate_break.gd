class_name GateBreak
## Phase 2/P8: Gate breaks -- game-initiated emergency events (§8b).
##
## Scope decision (flagged, no push-notification infra in this patch): the
## source's real trigger is a push notification / OS alert firing "on a
## schedule (weighted to evenings) and/or randomly", with a "limited
## response window" creating urgency to open the app right then. Building
## that for real means scheduled local notifications (Android AlarmManager/
## WorkManager + a system alert UI) -- a native-plugin-sized project on its
## own, bigger than this patch. v0 instead checks probabilistically
## whenever the app is already in the foreground (piggybacking on GPS
## location updates, which already fire periodically while playing),
## weighting the roll by the CURRENT hour to approximate "weighted to
## evenings". There is no real push and no enforced response window --
## accepting/dismissing is just a button, no countdown. Flagged as a real
## gap versus the source's actual "pulls you back into the app" hook.
##
## Reward: "bigger breaks give bigger rewards" with no concrete numbers or
## break-size tiers given anywhere -- v0 has one flat break size/reward
## multiplier (BREAK_REWARD_MULTIPLIER), not a range of break sizes.

const MIN_INTERVAL_SECONDS := 4 * 60 * 60  ## invented v0: 4h cooldown between offers
const BASE_CHANCE := 0.15  ## invented v0: per-check trigger chance outside evening hours
const EVENING_CHANCE_MULTIPLIER := 3.0  ## invented v0: "weighted to evenings"
const EVENING_START_HOUR := 18  ## inclusive, local time, 24h clock
const EVENING_END_HOUR := 23  ## inclusive
const BREAK_REWARD_MULTIPLIER := 1.5  ## invented v0: "bigger breaks give bigger rewards"
const BREAK_TICKET_BONUS := 1  ## invented v0: a break also grants this many gate tickets


## Whether a Gate Break should be offered right now. Pure -- `now_unix` and
## `hour_of_day` (0-23, local time) come from the scene layer (Time.* calls
## aren't available in core/). False if the cooldown since `last_offer_unix`
## (0 = never offered) hasn't elapsed yet.
static func should_trigger(
	now_unix: int, last_offer_unix: int, hour_of_day: int, rng: RandomNumberGenerator = null
) -> bool:
	if last_offer_unix != 0 and now_unix - last_offer_unix < MIN_INTERVAL_SECONDS:
		return false
	var chance := BASE_CHANCE
	if hour_of_day >= EVENING_START_HOUR and hour_of_day <= EVENING_END_HOUR:
		chance *= EVENING_CHANCE_MULTIPLIER
	var roll := rng.randf() if rng else randf()
	return roll < chance


## The boosted Essence reward for accepting a break gate, on top of the
## normal per-rank gate reward (GameLogic.essence_for_gate).
static func bonus_essence(base_essence: int) -> int:
	return int(round(base_essence * BREAK_REWARD_MULTIPLIER))
