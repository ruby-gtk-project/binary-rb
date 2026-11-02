# frozen_string_literal: true

# Number-base conversion, ported from the upstream get_answer.py / bit_count.py.
#
# The two sentinel strings are upstream's: "char" means the input is not valid
# in its own base, "char_dual" means the same but the two bases are equal, so
# both entries get flagged rather than just the input one. ABORT is this port's
# name for upstream's third outcome — the crash described on #answer.
module Converter
  DIGITS = '0123456789abcdefghijklmnopqrstuvwxyz'

  # Upstream's `+` crash, reproduced rather than fixed: src/lib/get_answer.py:57
  # reads `if '+' in input: split_input('')`, which calls a list and raises
  # TypeError, and the handler it was called from (src/window.py:100) never
  # finishes. Nothing the user can see changes — no answer, no error styling,
  # no bit count. The window does the same nothing when it sees this.
  ABORT = 'abort'

  module_function

  # Convert +input+ from +in_base+ to +out_base+, or return one of the three
  # sentinels. The checks run in upstream's order — space, then "+", then a
  # leading "-" — so "+ " is "char" and "+5" aborts, exactly as upstream's do.
  def answer(input, in_base, out_base)
    if input.include?(' ')
      'char'
    elsif input.include?('+')
      ABORT
    elsif input.start_with?('-')
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

  # A part is valid when upstream's `int(part, base)`
  # (src/lib/get_answer.py:66) would parse it: a run of digits legal in +base+,
  # optionally separated by single underscores, which Python's int() accepts
  # and Ruby's Integer() accepts on the same terms. So "1_0" in base 2 is 2 in
  # both apps, and "_10", "10_" and "1__0" are rejected by both. No sign, no
  # "0x" prefix and no whitespace: int() takes those only in base 10 or with a
  # matching prefix, neither of which can reach here.
  def valid?(part, base)
    DIGITS[0, base].then do |digits|
      part.match?(/\A[#{digits}](?:_?[#{digits}])*\z/i)
    end
  end

  # Upstream refuses any input containing "." unless the two bases are equal
  # (src/lib/get_answer.py:84, where a comment asks for the fractional case to
  # be calculated separately one day), in which case the input is echoed back
  # untouched. The port is faithful to that: a
  # user who types "10.1" gets an error on both sides, in both apps. That is
  # upstream's debt, not this port's licence to keep it — closing it here means
  # closing it upstream first, where the behaviour is decided.
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
