# frozen_string_literal: true

# Number-base conversion, ported from the upstream get_answer.py / bit_count.py.
#
# The two sentinel strings are upstream's: "char" means the input is not valid
# in its own base, "char_dual" means the same but the two bases are equal, so
# both entries get flagged rather than just the input one.
module Converter
  DIGITS = '0123456789abcdefghijklmnopqrstuvwxyz'

  module_function

  # Convert +input+ from +in_base+ to +out_base+, or return "char"/"char_dual".
  def answer(input, in_base, out_base)
    if input.include?(' ') || input.start_with?('-')
      'char'
    # -1 keeps trailing empty parts, so "1." is a part that fails to parse
    # rather than a bare "1" that succeeds — Ruby drops them by default,
    # Python's str.split never did.
    elsif input.split('.', -1).all? { |part| valid?(part, in_base) }
      convert(input, in_base, out_base)
    elsif in_base == out_base
      'char_dual'
    else
      'char'
    end
  end

  # A part is valid when it is a non-empty run of digits legal in +base+.
  # Deliberately stricter than Integer(): no sign, no underscores, no 0x
  # prefix, no whitespace — upstream rejects all of those too.
  def valid?(part, base)
    part.match?(/\A[#{DIGITS[0, base]}]+\z/i)
  end

  # Upstream never implemented fractional parts: anything with a "." falls
  # through to "char" unless the bases are equal, in which case the input is
  # echoed back untouched.
  def convert(input, in_base, out_base)
    if in_base == out_base
      input
    elsif input.include?('.')
      'char'
    else
      Integer(input, in_base).to_s(out_base).upcase
    end
  end

  # "1010" -> "8 + 2 = 1010". Faithful to upstream, quirks included: the sum is
  # over the '1' digits read as binary place values, while the right-hand side
  # is the input read as *decimal*, and is dropped entirely when the input is
  # not decimal (upstream swallowed the int() failure and kept the partial
  # string, trailing " + " and all).
  def bit_count(input)
    input.chars.filter_map.with_index do |char, index|
      if char == '1'
        1 << (input.length - 1 - index)
      end
    end.map { |bit| "#{bit} + " }.join.then do |sum|
      if input.match?(/\A[0-9]+\z/)
        "#{sum[0..-3]}= #{input.to_i}"
      else
        sum
      end
    end
  end
end
