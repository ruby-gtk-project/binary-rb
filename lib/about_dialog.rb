# frozen_string_literal: true

require 'adwaita'

require_relative 'i18n'

# The About dialog.
#
# Ported from src/main.py's on_about_action (src/main.py:70-77), which builds it
# with Adw.AboutDialog.new_from_appdata("io/github/fizzyizzy05/binary/metainfo.xml",
# "5.4") and then overrides the developers, the designers, the translator
# credits and the copyright.
#
# There is no GResource bundle here, so new_from_appdata has no resource path to
# read: the same metainfo file is read off disk instead, its
# <release version="5.4"> notes pulled out of it, and the fields appdata would
# have filled are set explicitly.
#
# Only those fields. adw_about_dialog_new_from_appdata sets application-name,
# application-icon, developer-name, version, release-notes,
# release-notes-version, license-type, website, issue-url and support-url, and
# it does not set `comments` — so neither does this, although the metainfo
# carries a <description> that would read well there. A description paragraph
# under the app name is a line upstream's About dialog does not show. The
# support-url appdata would have filled is absent here for the same reason it
# is absent there: the metainfo declares no <url type="help">.
class AboutDialog
  # The same file AdwAboutDialog.new_from_appdata reads out of upstream's
  # GResource bundle. The port ships it byte-identical, so the About dialog's
  # description and release notes are read out of it here.
  METAINFO = File.expand_path(
    '../data/io.github.fizzyizzy05.binary.metainfo.xml.in',
    __dir__,
  )

  # The <release version="…"> whose notes the dialog shows, with the
  # <description> body captured as the AppStream markup AdwAboutDialog wants.
  RELEASE_NOTES = lambda do |version|
    %r{<release\s+version="#{Regexp.escape(version)}"[^>]*>\s*<description>(.*?)</description>}m
  end

  def initialize(app_id:, version:)
    @app_id = app_id
    @version = version
  end

  # Nothing to assemble — an AdwAboutDialog takes no children — so building it
  # is the memoized dialog and its properties.
  def build = dialog

  # The release notes AdwAboutDialog.new_from_appdata would have taken from
  # data/io.github.fizzyizzy05.binary.metainfo.xml.in:30-53.
  def release_notes
    @release_notes ||= File.read(METAINFO)
      .match(RELEASE_NOTES.call(@version))
      .then { |found| found[1].strip }
  end

  def dialog
    @dialog ||= Adwaita::AboutDialog.new.tap do |about|
      about.application_name = _('Binary')
      about.application_icon = @app_id
      about.version = @version
      about.release_notes_version = @version
      about.release_notes = release_notes
      about.developer_name = 'Isabelle Jackson'
      about.developers = ['Isabelle Jackson https://fizzyizzy05.dev']
      about.designers = ['Gregor Niehl https://gitlab.gnome.org/gregorni']
      about.copyright = '© 2023-2024 Isabelle Jackson.'
      about.license_type = Gtk::License::GPL_3_0
      about.website = 'https://apps.gnome.org/Binary/'
      about.issue_url = 'https://github.com/fizzyizzy05/binary/issues'
      # Translators: Replace "translator-credits" with your names, one name per line
      about.translator_credits = _('translator-credits')
    end
  end
end
