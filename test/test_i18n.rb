# frozen_string_literal: true

require_relative 'test_helper'

require 'i18n'

# The catalogues are upstream's, compiled by `rake translations`. German is the
# probe language because it translates every string these tests look at, and
# LANGUAGE selects it without needing a de_DE locale generated on the machine.
class TestI18n < Minitest::Test
  def setup
    ENV['LC_ALL'] = 'en_GB.UTF-8'
    ENV['LANGUAGE'] = 'de'
    I18n.bind(File.join(ROOT, 'locale'))
  end

  def teardown
    ENV.delete('LANGUAGE')
    I18n.bind(File.join(ROOT, 'locale'))
  end

  def test_plain_messages_come_back_translated
    assert_equal 'Oktal', _('Octal')
    assert_equal 'Ungültige Eingabe', _('Invalid input')
    assert_equal 'Hauptmenü', _('Main Menu')
  end

  def test_translations_are_utf_8
    assert_equal Encoding::UTF_8, _('Invalid input').encoding
  end

  # The catalogues carry Python's "%(name)d" placeholders and the plural rules
  # for each language, so both have to survive the crossing.
  def test_plurals_pick_the_right_form_and_take_the_count
    assert_equal '1 Bit', n_('%(in_count)d bit', '%(in_count)d bits', 1)
    assert_equal '6 Bits', n_('%(in_count)d bit', '%(in_count)d bits', 6)
    assert_equal '0 Bits', n_('%(out_count)d bit', '%(out_count)d bits', 0)
  end

  def test_contextual_messages_are_looked_up_under_their_context
    assert_equal 'Schließen', c_('shortcut window', 'Quit')
    assert_equal 'Allgemein', c_('shortcut window', 'General')
  end

  # A context with no entry has to fall back to the message, not leak the
  # separator byte into the interface.
  def test_a_missing_context_falls_back_to_the_message
    assert_equal 'Quit', c_('no such context', 'Quit')
  end

  # Upstream asks for the base names out of a domain nothing defines, so they
  # stay English. Translating them here would be a difference, not a fix.
  def test_the_number_base_domain_stays_untranslated
    assert_equal 'Binary', d_('Number base', 'Binary')
  end

  def test_an_unknown_message_comes_back_unchanged
    assert_equal 'not in any catalogue', _('not in any catalogue')
  end
end
