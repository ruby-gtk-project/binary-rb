# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'

require 'settings'

class TestSettings < Minitest::Test
  def test_defaults_when_there_is_no_file_yet
    Dir.mktmpdir do |dir|
      Settings.new(path: File.join(dir, 'settings.json')).then do |settings|
        assert_equal 0, settings['input_base']
        assert_equal 2, settings['output_base']
      end
    end
  end

  def test_round_trips_through_the_file
    Dir.mktmpdir do |dir|
      File.join(dir, 'nested', 'settings.json').then do |path|
        Settings.new(path: path).tap do |settings|
          settings['input_base'] = 3
          settings['output_base'] = 1
          settings.save
        end

        assert_equal 3, Settings.new(path: path)['input_base']
        assert_equal 1, Settings.new(path: path)['output_base']
      end
    end
  end

  def test_a_corrupt_file_falls_back_to_the_defaults
    Dir.mktmpdir do |dir|
      File.join(dir, 'settings.json').then do |path|
        File.write(path, 'not json')

        assert_equal 0, Settings.new(path: path)['input_base']
      end
    end
  end
end
