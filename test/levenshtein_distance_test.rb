# File: levenshtein_distance_test.rb

require_relative "../lib/globals"
require "minitest/autorun"

class LevenshteinDistanceTest < Minitest::Test
  def test_levenshtein_distance
    assert_equal [0, "MMM"], levenshtein_distance("cat", "cat")
    assert_equal [1, "SMM"], levenshtein_distance("cat", "bat") 
    assert_equal [4, "DSSS"], levenshtein_distance("cats", "dog")
    assert_equal [3, "MMMDDD"], levenshtein_distance("kitten", "kit")
    assert_equal [1, "IMMMM"], levenshtein_distance("cats", "scats")    

    assert_raises(ArgumentError) { levenshtein_distance("cat") }
    assert_raises(ArgumentError) { levenshtein_distance(123, 456) }

    assert_equal [5, "SSSSS"], levenshtein_distance("アイウエオ", "カキクケコ")
  end

  def test_equal_strings
    dist, _ = levenshtein_distance("hello", "hello")
    assert_equal 0, dist
  end

  def test_empty_string
    dist, _ = levenshtein_distance("", "hello")
    assert_equal 5, dist
  end

  def test_case_insensitivity
    dist, _ = levenshtein_distance("HELLO", "hello")
    assert_equal 5, dist
  end

  def test_non_string_input
    assert_raises(ArgumentError) { levenshtein_distance(123, "hello") }
  end

  def test_special_characters
    dist, _ = levenshtein_distance("hello@", "hello$@")
    assert_equal 1, dist
  end

  def test_null_input
    assert_raises(ArgumentError) { levenshtein_distance(nil, "hello") }
  end

  def test_white_space_leading_trailing
    dist, _ = levenshtein_distance(" hello ", "hello")
    assert_equal 2, dist
  end

  def test_only_white_spaces
    dist, _ = levenshtein_distance("     ", "     ")
    assert_equal 0, dist
  end

  def test_oversized_string
    # TODO: Implement a long string for performance testing
    pass
  end

  def test_multi_word_strings
    dist, _ = levenshtein_distance("hello world", "hallo wereld")
    assert_equal 3, dist
  end

  def test_unicode_characters
    dist, _ = levenshtein_distance("héllo", "hello")
    assert_equal 1, dist
  end

end
