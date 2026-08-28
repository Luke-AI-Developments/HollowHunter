# tests/unit/test_text_filter.gd
extends GutTest
## TextFilter: nickname length + v0 profanity-blocklist validation.


func test_empty_string_is_valid() -> void:
	assert_true(TextFilter.is_valid_nickname(""))


func test_whitespace_only_is_valid() -> void:
	assert_true(TextFilter.is_valid_nickname("   "))


func test_normal_name_within_length_is_valid() -> void:
	assert_true(TextFilter.is_valid_nickname("Duskfang"))


func test_name_at_exactly_max_length_is_valid() -> void:
	assert_true(TextFilter.is_valid_nickname("a".repeat(TextFilter.MAX_LENGTH)))


func test_name_over_max_length_is_invalid() -> void:
	assert_false(TextFilter.is_valid_nickname("a".repeat(TextFilter.MAX_LENGTH + 1)))


func test_blocked_word_is_invalid() -> void:
	assert_false(TextFilter.is_valid_nickname("fuck"))


func test_blocked_word_is_invalid_case_insensitive() -> void:
	assert_false(TextFilter.is_valid_nickname("FuCk"))


func test_blocked_word_as_substring_is_invalid() -> void:
	assert_false(TextFilter.is_valid_nickname("xfuckx"))


func test_leading_trailing_whitespace_does_not_count_toward_length() -> void:
	assert_true(TextFilter.is_valid_nickname("  " + "a".repeat(TextFilter.MAX_LENGTH) + "  "))


func test_sanitize_trims_leading_and_trailing_whitespace() -> void:
	assert_eq(TextFilter.sanitize_nickname("  Duskfang  "), "Duskfang")
