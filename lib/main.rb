# frozen_string_literal: true

require 'adwaita'

require_relative 'i18n'
require_relative 'settings'
require_relative 'window'

# The application singleton: actions, accelerators, and the windows.
class BinaryApp
  attr_reader :windows

  APP_ID = 'io.github.fizzyizzy05.binary'
  VERSION = '5.4'

  # The same file AdwAboutDialog.new_from_appdata reads out of upstream's
  # GResource bundle (src/main.py:71). The port ships it byte-identical, so the
  # About dialog's description and release notes are read out of it here.
  METAINFO = File.expand_path(
    '../data/io.github.fizzyizzy05.binary.metainfo.xml.in',
    __dir__,
  )

  # The <release version="…"> whose notes the About dialog shows, with the
  # <description> body captured as the AppStream markup AdwAboutDialog wants.
  RELEASE_NOTES = lambda do |version|
    %r{<release\s+version="#{Regexp.escape(version)}"[^>]*>\s*<description>(.*?)</description>}m
  end

  # The short option name upstream passes as the byte b"w" (src/main.py:46).
  NEW_WINDOW_SHORT = 'w'.ord

  ACTIONS = {
    'quit'         => ['<primary>q'],
    'about'        => [],
    'preferences'  => [],
    'close-window' => ['<primary>w'],
    'new-window'   => ['<primary>n'],
    'shortcuts'    => ['<primary>question'],
  }.freeze

  HIGH_CONTRAST_PRIORITY = Gtk::StyleProvider::PRIORITY_APPLICATION + 1

  # Message catalogues live beside the source when running from a checkout and
  # in the system locale directory once installed.
  LOCALE_DIRECTORIES = [
    File.expand_path('../locale', __dir__),
    '/usr/share/locale',
  ].freeze

  def initialize(settings: Settings.new)
    @settings = settings
    @windows = []
    I18n.bind(LOCALE_DIRECTORIES.find { |dir| File.directory?(dir) })
  end

  def build
    app.tap do |a|
      ACTIONS.each do |name, accels|
        a.add_action(action_for(name))
        a.set_accels_for_action("app.#{name}", accels)
      end

      a.signal_connect('startup') do
        # libadwaita has to be initialised before its style manager exists;
        # Gtk::Application does not do it the way AdwApplication would.
        Adwaita.init
        install_styles
        install_icons
      end

      a.signal_connect('activate') { present_window }

      # Upstream's do_handle_local_options (src/main.py:57): --new-window
      # registers, and a second invocation that finds itself remote hands the
      # action to the instance already running and exits 0. Anything else
      # returns -1, which is GLib's "carry on with the normal startup".
      a.signal_connect('handle-local-options') do |_, options|
        handle_local_options(options)
      end

      # HANDLES_COMMAND_LINE is what carries `--new-window` from a second
      # invocation over to the instance that is already running.
      a.signal_connect('command-line') do |_, command_line|
        handle_command_line(command_line.arguments)
        0
      end
    end
  end

  # $0 goes back on the front: g_application_run takes a C argv and skips its
  # first element as the program name, while Ruby's ARGV has no program name in
  # it, so a bare `app.run(ARGV)` eats the first argument — `binary --help`
  # opened a window instead of printing anything. Upstream passes sys.argv,
  # which carries argv[0] (src/main.py:106).
  def run = app.run([$PROGRAM_NAME, *ARGV])

  def handle_local_options(options)
    if options.contains?('new-window')
      forward_new_window
    else
      -1
    end
  end

  def forward_new_window
    app.register
    if app.remote?
      app.activate_action('new-window', nil)
      0
    else
      -1
    end
  end

  def handle_command_line(arguments)
    if arguments.include?('--new-window') || arguments.include?('-w')
      new_window
    else
      app.activate
    end
  end

  def present_window
    if active_window
      active_window.present
    else
      new_window
    end
  end

  def new_window
    # Kept in @windows so the Ruby object — and the signal handlers closed over
    # it — outlives the call; the application only holds the Gtk window.
    BinaryWindow.new(app: app, settings: @settings).tap do |win|
      @windows << win
      win.build
      win.present
    end
  end

  def action_for(name)
    Gio::SimpleAction.new(name).tap do |action|
      action.signal_connect('activate') { activate_action(name) }
    end
  end

  def activate_action(name)
    case name
    when 'quit' then app.quit
    when 'about' then about_dialog.present(active_window)
    when 'preferences' then preferences_dialog.present(active_window)
    when 'shortcuts' then shortcuts_dialog.present(active_window)
    when 'close-window' then active_window&.close
    when 'new-window' then new_window
    end
  end

  def active_window = app.active_window

  # Upstream keeps both stylesheets in its GResource bundle, where
  # GtkApplication loads style.css for every look and style-hc.css only while
  # high contrast is in effect. The port has no bundle, so that keying is done
  # by hand: the base sheet stays on the display for good, and the
  # high-contrast one is added and removed as AdwStyleManager:high-contrast
  # flips.
  def install_styles
    Gtk::StyleContext.add_provider_for_display(
      display,
      style_provider,
      Gtk::StyleProvider::PRIORITY_APPLICATION,
    )

    style_manager.tap do |manager|
      manager.signal_connect('notify::high-contrast') { sync_high_contrast }
    end

    sync_high_contrast
  end

  # Both sheets give .typing-label an opacity, so the high-contrast provider
  # sits one step above the base priority and wins while it is on the display.
  def sync_high_contrast
    if style_manager.high_contrast?
      Gtk::StyleContext.add_provider_for_display(
        display,
        high_contrast_provider,
        HIGH_CONTRAST_PRIORITY,
      )
    else
      Gtk::StyleContext.remove_provider_for_display(display, high_contrast_provider)
    end
  end

  def display = @display ||= Gdk::Display.default

  def style_manager = @style_manager ||= Adwaita::StyleManager.default

  def style_provider
    @style_provider ||= Gtk::CssProvider.new.tap do |provider|
      provider.load(data: STYLE)
    end
  end

  def high_contrast_provider
    @high_contrast_provider ||= Gtk::CssProvider.new.tap do |provider|
      provider.load(data: HIGH_CONTRAST_STYLE)
    end
  end

  # Upstream ships vertical-arrows-symbolic inside its GResource bundle. A
  # search path onto the same SVG is the same icon with nothing to compile.
  def install_icons
    Gtk::IconTheme.get_for_display(Gdk::Display.default)
      .add_search_path(File.expand_path('../data/icons', __dir__))
  end

  def app
    @app ||= Gtk::Application.new(APP_ID, :handles_command_line).tap do |a|
      Gtk::Window.set_default_icon_name(APP_ID)

      # Registering the option with GLib is what puts "-w, --new-window" in
      # `binary --help` and makes GLib reject an option nobody declared, as
      # upstream's add_main_option does (src/main.py:46). The description is
      # the English one upstream passes; it marks no msgid there either.
      a.add_main_option(
        'new-window',
        NEW_WINDOW_SHORT,
        :none,
        :none,
        'Open a new window',
        nil,
      )
    end
  end

  # The release notes AdwAboutDialog.new_from_appdata would have taken from
  # data/io.github.fizzyizzy05.binary.metainfo.xml.in:30-53.
  def release_notes
    @release_notes ||= File.read(METAINFO)
      .match(RELEASE_NOTES.call(VERSION))
      .then { |found| found[1].strip }
  end

  # Built on every activation, not memoized: upstream makes a new
  # Adw.AboutDialog each time the action runs (src/main.py:70), so no dialog
  # instance is ever shared between two windows.
  def about_dialog
    Adwaita::AboutDialog.new.tap do |about|
      about.application_name = _('Binary')
      about.application_icon = APP_ID
      about.version = VERSION
      about.comments = _('A small and simple app used to convert between different hexadecimal and binary numbers')
      about.release_notes_version = VERSION
      about.release_notes = release_notes
      about.developer_name = 'Isabelle Jackson'
      about.developers = ['Isabelle Jackson https://fizzyizzy05.dev']
      about.designers = ['Gregor Niehl https://gitlab.gnome.org/gregorni']
      about.copyright = '© 2023-2024 Isabelle Jackson.'
      about.license_type = Gtk::License::GPL_3_0
      about.website = 'https://apps.gnome.org/Binary/'
      about.issue_url = 'https://github.com/fizzyizzy05/binary/issues'
      # Translators put their own names here; the catalogues carry them.
      about.translator_credits = _('translator-credits')
    end
  end

  # Upstream's preferences window is an empty page — the action exists so the
  # desktop shell can open it, and there is nothing in it yet.
  # src/preferences.blp:6-8 gives the window default-width 400,
  # default-height 306 and height-request 200. AdwDialog has no default size —
  # content-width and content-height are its name for the same thing, and
  # #set_default_size does not exist on it in the bindings — so the first two
  # land there and the minimum height stays a size request.
  def preferences_dialog
    @preferences_dialog ||= Adwaita::PreferencesDialog.new.tap do |dialog|
      dialog.title = _('Preferences')
      dialog.content_width = 400
      dialog.content_height = 306
      dialog.set_size_request(-1, 200)
      dialog.add(Adwaita::PreferencesPage.new)
    end
  end

  def shortcuts_dialog
    @shortcuts_dialog ||= Adwaita::ShortcutsDialog.new.tap do |dialog|
      dialog.add(general_shortcuts)
    end
  end

  # One c_ call per item, with the context and the msgid written out, because a
  # table of titles walked in a loop is five msgids xgettext cannot see — and a
  # msgid that does not reach po/binary.pot is marked obsolete in all 32
  # catalogues on the next `rake pot`. Upstream writes them out the same way,
  # in src/shortcuts-dialog.blp:6, :9, :14, :19, :24.
  def general_shortcuts
    @general_shortcuts ||= Adwaita::ShortcutsSection.new.tap do |section|
      section.title = c_('shortcut window', 'General')

      section.add(shortcut_item(c_('shortcut window', 'New Window'), 'app.new-window'))
      section.add(shortcut_item(c_('shortcut window', 'Close Window'), 'app.close-window'))
      section.add(shortcut_item(c_('shortcut window', 'Show Shortcuts'), 'app.shortcuts'))
      section.add(shortcut_item(c_('shortcut window', 'Quit'), 'app.quit'))
    end
  end

  # Both two-argument constructors take (title, String), and the bindings
  # always resolve that to the accelerator one — hence the empty accelerator
  # and the setter for the action name.
  def shortcut_item(title, action)
    Adwaita::ShortcutsItem.new(title, '').tap do |item|
      item.action_name = action
    end
  end

  STYLE = <<~CSS
    .bitLbl {
      font-size: 0.9em;
    }

    .flat-dropdown button:not(:checked):not(:hover) {
      background: transparent;
      box-shadow: none;
    }

    .typing-label {
      font-size: 0.9em;
      opacity: 0.5;
      font-weight: 700;
    }
  CSS

  # Ported from src/style-hc.css: the one rule the high-contrast look changes,
  # lifting the typing label out of the 0.5 opacity the base sheet gives it.
  HIGH_CONTRAST_STYLE = <<~CSS
    .typing-label {
      opacity: 0.75;
    }
  CSS
end
