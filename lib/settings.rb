# frozen_string_literal: true

require 'adwaita'

# The app's GSettings, under upstream's schema and key names, so an installed
# copy of this port and an installed copy of upstream read and write the same
# stored preferences.
#
# The schema has to exist before Gio::Settings will hand one out at all —
# `rake schemas` compiles it into data/schemas, and bin/binary puts that
# directory on GSETTINGS_SCHEMA_DIR when running from a checkout.
class Settings
  SCHEMA_ID = 'io.github.fizzyizzy05.binary'

  def initialize(schema_id: SCHEMA_ID)
    @schema_id = schema_id
  end

  def [](key)
    settings.get_int(key)
  end

  # GSettings writes through immediately; there is nothing to flush.
  def []=(key, value)
    settings.set_int(key, value)
  end

  def settings = @settings ||= Gio::Settings.new(@schema_id)
end
