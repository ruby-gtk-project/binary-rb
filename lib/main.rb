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

  # The description AdwAboutDialog.new_from_appdata would have read out of the
  # metainfo file, wrapped exactly as the catalogues have it.
  SUMMARY = 'A small and simple app used to convert between different ' \
            'hexadecimal and binary numbers'

  ACTIONS = {
    'quit'         => ['<primary>q'],
    'about'        => [],
    'preferences'  => [],
    'close-window' => ['<primary>w'],
    'new-window'   => ['<primary>n'],
    'shortcuts'    => ['<primary>question'],
  }.freeze

  # Translated out of the "shortcut window" context, as upstream's
  # shortcuts-dialog.blp asks for them.
  SHORTCUTS = [
    ['New Window', 'app.new-window'],
    ['Close Window', 'app.close-window'],
    ['Show Shortcuts', 'app.shortcuts'],
    ['Quit', 'app.quit'],
  ].freeze

  SHORTCUT_CONTEXT = 'shortcut window'

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
        install_styles
        install_icons
      end

      a.signal_connect('activate') { present_window }

      # HANDLES_COMMAND_LINE is what carries `--new-window` from a second
      # invocation over to the instance that is already running.
      a.signal_connect('command-line') do |_, command_line|
        handle_command_line(command_line.arguments)
        0
      end
    end
  end

  def run = app.run(ARGV)

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

  def install_styles
    Gtk::CssProvider.new.tap do |provider|
      provider.load(data: STYLE)
      Gtk::StyleContext.add_provider_for_display(
        Gdk::Display.default,
        provider,
        Gtk::StyleProvider::PRIORITY_APPLICATION,
      )
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
    end
  end

  def about_dialog
    @about_dialog ||= Adwaita::AboutDialog.new.tap do |about|
      about.application_name = _('Binary')
      about.application_icon = APP_ID
      about.version = VERSION
      about.comments = _(SUMMARY)
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
  def preferences_dialog
    @preferences_dialog ||= Adwaita::PreferencesDialog.new.tap do |dialog|
      dialog.title = _('Preferences')
      dialog.add(Adwaita::PreferencesPage.new)
    end
  end

  def shortcuts_dialog
    @shortcuts_dialog ||= Adwaita::ShortcutsDialog.new.tap do |dialog|
      dialog.add(general_shortcuts)
    end
  end

  def general_shortcuts
    @general_shortcuts ||= Adwaita::ShortcutsSection.new.tap do |section|
      section.title = c_(SHORTCUT_CONTEXT, 'General')

      SHORTCUTS.each do |title, action|
        section.add(shortcut_item(c_(SHORTCUT_CONTEXT, title), action))
      end
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
end
