# frozen_string_literal: true

require 'adwaita'

require_relative 'i18n'

# The Preferences dialog: an empty page.
#
# Ported from src/preferences.blp and src/preferences.py. The blueprint is an
# Adw.PreferencesWindow holding one Adw.PreferencesPage with no groups and no
# rows, and the Python class behind it only reads the GSettings object and
# stores it — nothing is bound, nothing is shown. The action exists so the
# desktop shell can open it; there is nothing in it yet, upstream or here.
#
# src/preferences.blp:6-8 gives the window default-width 400, default-height 306
# and height-request 200. The port substitutes Adwaita::PreferencesDialog
# because the window class is deprecated, and AdwDialog has no default size —
# content-width and content-height are its name for the same thing, and
# #set_default_size does not exist on it in the bindings — so the first two land
# there and the minimum height stays a size request.
class PreferencesDialog
  def build
    dialog.tap do |prefs|
      prefs.add(page)
    end
  end

  def dialog
    @dialog ||= Adwaita::PreferencesDialog.new.tap do |prefs|
      prefs.title = _('Preferences')
      prefs.content_width = 400
      prefs.content_height = 306
      prefs.set_size_request(-1, 200)
    end
  end

  def page = @page ||= Adwaita::PreferencesPage.new
end
