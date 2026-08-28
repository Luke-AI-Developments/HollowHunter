# core/text_filter.gd
class_name TextFilter
## Pure text-input validation for anywhere the player types a short custom
## name -- currently just shadow nicknames (§6c). Factored out on its own,
## not folded into HunterState, so a future hunter/display-name input can
## reuse MAX_LENGTH / the blocklist instead of duplicating one.
##
## The blocklist is a hardcoded v0 list, not a real profanity-detection
## library -- it won't catch l33tspeak / spacing evasion. Flagged as a real
## gap if this ever needs to be robust, same "good enough for v0" bar as
## every other invented number in this project (see ShadowLeveling).

const MAX_LENGTH := 20

## v0 blocklist -- invented, not exhaustive. Case-insensitive substring
## match, so it also catches embedded uses (e.g. "xfuckx").
const _BLOCKED_SUBSTRINGS := [
	"fuck",
	"shit",
	"cunt",
	"nigger",
	"nigga",
	"faggot",
	"fag",
	"retard",
	"whore",
	"slut",
	"rape",
	"nazi",
	"hitler",
]


## Empty/whitespace-only text is always valid -- it means "use the default
## species name," a skip, not a rejected value. Otherwise: must fit
## MAX_LENGTH (after trimming) and contain no blocked word.
static func is_valid_nickname(text: String) -> bool:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return true
	if trimmed.length() > MAX_LENGTH:
		return false
	return not _contains_blocked_word(trimmed)


static func sanitize_nickname(text: String) -> String:
	return text.strip_edges()


static func _contains_blocked_word(text: String) -> bool:
	var lower := text.to_lower()
	for word in _BLOCKED_SUBSTRINGS:
		if lower.contains(word):
			return true
	return false
