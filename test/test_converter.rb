# frozen_string_literal: true

require_relative 'test_helper'

require 'converter'

class TestConverter < Minitest::Test
  def test_converts_between_the_four_named_bases
    assert_equal '42', Converter.answer('101010', 2, 10)
    assert_equal '101010', Converter.answer('42', 10, 2)
    assert_equal '4B1', Converter.answer('1201', 10, 16)
    assert_equal 'F', Converter.answer('17', 8, 16)
  end

  def test_letters_come_back_upper_case_and_are_accepted_in_either_case
    assert_equal 'FF', Converter.answer('255', 10, 16)
    assert_equal '255', Converter.answer('ff', 16, 10)
    assert_equal '255', Converter.answer('FF', 16, 10)
  end

  def test_bases_up_to_thirty_six
    assert_equal 'Z', Converter.answer('35', 10, 36)
    assert_equal '35', Converter.answer('z', 36, 10)
  end

  def test_zero_round_trips
    assert_equal '0', Converter.answer('0', 10, 2)
    assert_equal '0', Converter.answer('0', 2, 16)
  end

  def test_equal_bases_echo_the_input_untouched
    assert_equal '1201', Converter.answer('1201', 10, 10)
    assert_equal '1.5', Converter.answer('1.5', 10, 10)
  end

  def test_digits_outside_the_base_are_rejected
    assert_equal 'char', Converter.answer('2', 2, 10)
    assert_equal 'char', Converter.answer('9', 8, 10)
    assert_equal 'char', Converter.answer('G', 16, 10)
  end

  def test_invalid_input_in_a_single_base_flags_both_entries
    assert_equal 'char_dual', Converter.answer('2', 2, 2)
    assert_equal 'char_dual', Converter.answer('xyz', 10, 10)
  end

  def test_spaces_and_negatives_are_rejected_whatever_the_bases
    assert_equal 'char', Converter.answer('1 0', 2, 10)
    assert_equal 'char', Converter.answer('1 0', 2, 2)
    assert_equal 'char', Converter.answer('-5', 10, 2)
    assert_equal 'char', Converter.answer('-5', 10, 10)
  end

  def test_prefixes_underscores_and_signs_ruby_would_otherwise_accept
    assert_equal 'char', Converter.answer('0x1f', 16, 10)
    assert_equal 'char', Converter.answer('1_0', 10, 2)
    assert_equal 'char', Converter.answer('+5', 10, 2)
  end

  # Upstream never implemented fractional conversion; a "." only survives when
  # there is no conversion to do.
  def test_fractions_are_unsupported_across_bases
    assert_equal 'char', Converter.answer('1.5', 10, 2)
    assert_equal 'char', Converter.answer('1.0', 2, 10)
    assert_equal 'char', Converter.answer('1.', 10, 2)
    assert_equal 'char_dual', Converter.answer('1.', 10, 10)
  end

  def test_bit_count_sums_the_binary_place_values
    assert_equal '8 + 2 = 1010', Converter.bit_count('1010')
    assert_equal '1 = 1', Converter.bit_count('1')
    assert_equal '32 + 8 + 2 = 101010', Converter.bit_count('101010')
  end

  # Faithful to upstream: the right-hand side is the input read as decimal, so
  # it disappears entirely once the input is not decimal.
  def test_bit_count_on_non_decimal_and_empty_input
    assert_equal '', Converter.bit_count('')
    assert_equal '= 42', Converter.bit_count('42')
    assert_equal '', Converter.bit_count('FF')
    assert_equal '2 + ', Converter.bit_count('1F')
  end
end
