# frozen_string_literal: true

require 'json'
require 'fileutils'

# The two dropdown selections, remembered between runs.
#
# Upstream uses a GSettings schema, which has to be compiled and installed into
# a schema directory before the app will even start. A JSON file in the config
# directory buys the same behaviour with nothing to install.
class Settings
  DEFAULTS = { 'input_base' => 0, 'output_base' => 2 }.freeze

  def initialize(path: self.class.default_path)
    @path = path
  end

  def [](key)
    values.fetch(key, DEFAULTS[key])
  end

  def []=(key, value)
    values[key] = value
  end

  def save
    FileUtils.mkdir_p(File.dirname(@path))
    File.write(@path, JSON.pretty_generate(values))
  end

  def values
    @values ||= load_values
  end

  def load_values
    JSON.parse(File.read(@path))
  rescue Errno::ENOENT, JSON::ParserError
    DEFAULTS.dup
  end

  def self.default_path
    File.join(
      ENV.fetch('XDG_CONFIG_HOME', File.join(Dir.home, '.config')),
      'binary-rb',
      'settings.json',
    )
  end
end
