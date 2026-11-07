# frozen_string_literal: true

require 'adwaita'

require_relative 'about_dialog'
require_relative 'i18n'
require_relative 'preferences_dialog'
require_relative 'settings'
require_relative 'shortcuts_dialog'
require_relative 'window'

# The application singleton: actions, accelerators, and the windows.
class BinaryApp
  attr_reader :windows

  APP_ID = 'io.github.fizzyizzy05.binary'
  VERSION = '5.4'

  # The short option name upstream passes as the byte b"w" (src/main.py:46).
  NEW_WINDOW_SHORT = 'w'.ord

  ACTIONS = {
    'quit'         => ['<primary>q'],
    'about'        => [],
    'preferences'  => [],
    'close-window' => ['<primary>w'],
    'new-window'   => ['<primary>n'],
    # No accelerator: upstream binds none, because src/main.py never creates
    # this action at all — the menu item and the four shortcuts items that name
    # app.shortcuts are dead there. The port installs the action so the menu
    # item works, and stops there: an accelerator is derivable from nothing
    # upstream does, and because Adw.ShortcutsItem renders whatever the
    # application has bound to the action it names, binding one would also put
    # a shortcut in the shortcuts dialog that upstream's shows as blank.
    #
    # This is a decided, permanent divergence (PORTING.md item 6,
    # .reports/component-parity.md's "dead-reference fix" rule), not an
    # open question: the alternative — deleting this action so the menu item
    # and the four shortcuts-dialog rows that name it go back to doing
    # nothing — was considered and rejected, because it buys no fidelity a
    # user can tell apart from a second bug.
    'shortcuts'    => [],
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
    # DEFAULT_FLAGS is upstream's (src/main.py:34), and it is the flags that
    # make `binary nonsense-argument` fail: a GApplication with neither
    # HANDLES_OPEN nor HANDLES_COMMAND_LINE refuses a non-option argument.
    # Measured in this shell: GLib prints "GLib-GIO-CRITICAL **: This
    # application can not open files." and g_application_run returns 1, which
    # exe/binary exits with. Nothing here needs more than that — `--new-window`
    # from a second
    # invocation travels through #handle_local_options, #register and
    # #activate_action, which is the route upstream's do_handle_local_options
    # takes (src/main.py:57-64) and needs no command-line signal.
    @app ||= Gtk::Application.new(APP_ID, :default_flags).tap do |a|
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

  # Built on every activation, not memoized: upstream makes a new
  # Adw.AboutDialog each time the action runs (src/main.py:70), so no dialog
  # instance is ever shared between two windows.
  def about_dialog = AboutDialog.new(app_id: APP_ID, version: VERSION).build

  # Fresh per activation as well: upstream's on_preferences_action builds a new
  # PrefsWindow every time the action runs (src/main.py:79-83), so the dialog is
  # never an instance left over from another window.
  def preferences_dialog = PreferencesDialog.new.build

  # Upstream never opens its shortcuts dialog at all — src/main.py creates no
  # app.shortcuts action for the menu item and the dialog items that point at
  # it — so the port decides this one, and it decides it the way the other two
  # dialogs behave: a new dialog per activation rather than one instance
  # followed from window to window.
  def shortcuts_dialog = ShortcutsDialog.new.build

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
