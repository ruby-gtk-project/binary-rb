# frozen_string_literal: true

require_relative 'test_helper'

require 'settings'

class TestSettings < Minitest::Test
  KEYS = %w[input-base output-base group-digits].freeze

  # One memory backend serves the whole process, so each test starts by putting
  # the keys back to what the schema says.
  def setup
    @settings = Settings.new
    KEYS.each { |key| @settings.settings.reset(key) }
  end

  def test_the_schema_ships_upstreams_defaults
    assert_equal 0, @settings['input-base']
    assert_equal 2, @settings['output-base']
    assert_equal 0, @settings['group-digits']
  end

  def test_writes_are_readable_through_a_second_handle
    @settings['input-base'] = 3
    @settings['output-base'] = 1

    Settings.new.tap do |reopened|
      assert_equal 3, reopened['input-base']
      assert_equal 1, reopened['output-base']
    end
  end

  # The port and upstream have to agree on where preferences live, or
  # installing one over the other silently loses them.
  def test_uses_upstreams_schema_id
    assert_equal 'io.github.fizzyizzy05.binary', Settings::SCHEMA_ID
  end
end
