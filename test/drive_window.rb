# frozen_string_literal: true

# Drives the real window: types into the entries, switches bases, opens the
# menu dialogs, and writes screenshots to tmp/shots for eyeballing.

require 'English'
require 'fileutils'
require 'open3'

require_relative 'environment'
require_relative '../lib/main'
require_relative 'gtk_driver'

# The window under test is the one the app most recently made.
def window(app)
  app.windows.last
end

# Objects a later step has to compare against an earlier one.
SEEN = {}

# The options dict GLib hands to handle-local-options for `binary -w`. The
# value has to be a GLib::Variant — GLib::VariantDict#insert with a plain Ruby
# true segfaults the bindings (FINDINGS.md).
def new_window_options
  GLib::VariantDict.new(nil).tap do |options|
    options.insert('new-window', GLib::Variant.new(true))
  end
end

BinaryApp.new.then do |app|
  GtkDriver.drive(app, shots: 'tmp/shots') do |d, _|
    d.window { app.active_window }

    d.step('the window comes up') do
      d.check('window exists') { !app.active_window.nil? }
      d.check('input base is binary by default') { window(app).input_row.base == 2 }
      d.check('output base is decimal by default') { window(app).output_row.base == 10 }
      d.check('bit counter shows for binary input') { window(app).input_row.bit_button.visible? }
      d.check('bit counter hidden for decimal output') { !window(app).output_row.bit_button.visible? }
      d.check('base spin hidden until Other') { !window(app).input_row.spin.visible? }
      d.check('entries carry an accessible label') do
        [window(app).input_row.entry, window(app).output_row.entry].all? do |entry|
          Gtk.test_accessible_has_property(entry, Gtk::AccessibleProperty::LABEL)
        end
      end
      d.check('the dropdown lists all five bases') do
        window(app).input_row.dropdown.model.n_items == 5
      end
      d.shot('01-empty')
    end

    # Upstream's `editable` guard is False until something sets it True, and
    # what sets it is the `notify` handler in src/window.blp:112 — connected to
    # every property notification, so the set_model in src/window.py:67 fires
    # change_output_base, which runs to the end and sets editable = True before
    # __init__ returns. Typing into the output entry therefore works on a fresh
    # window in both apps, and this is the step that says so.
    d.step('typing into the output entry works on a fresh window') do
      window(app).output_row.entry.text = '2'
    end

    d.step('the input followed without a base change first') do
      d.check('input reads 10') { window(app).input_row.text == '10' }
      window(app).output_row.entry.text = ''
    end

    d.step('typing binary converts to decimal') do
      window(app).input_row.entry.text = '101010'
    end

    d.step('the answer and the bit breakdown appear') do
      d.check('output reads 42') { window(app).output_row.text == '42' }
      d.check('bit label counts the digits') { window(app).input_row.bit_button.label == '6 bits' }
      d.check('popover shows the sum') do
        window(app).input_row.bits_label.label == '32 + 8 + 2 = 101010'
      end
      d.check('entry went monospace') do
        window(app).input_row.entry.css_classes.include?('monospace')
      end
      d.check('no error styling') do
        !window(app).input_row.entry.css_classes.include?('error')
      end
      d.shot('02-binary-to-decimal')
    end

    d.step('typing into the output converts backwards') do
      window(app).output_row.entry.text = '255'
    end

    d.step('the input follows the output') do
      d.check('input reads 11111111') { window(app).input_row.text == '11111111' }
      d.shot('03-decimal-to-binary')
    end

    # Typed a character at a time, the way a user does it. Assigning to `text`
    # would clear the entry first, and the empty-string pass that follows
    # blanks the other side before the invalid digit ever arrives.
    d.step('an invalid digit for the base is rejected') do
      window(app).input_row.entry.buffer.insert_text(8, '2', 1)
    end

    d.step('the input is flagged and the output left alone') do
      d.check('input reads 111111112') { window(app).input_row.text == '111111112' }
      d.check('input has the error class') do
        window(app).input_row.entry.css_classes.include?('error')
      end
      d.check('input is tooltipped') do
        window(app).input_row.entry.tooltip_text == 'Invalid input'
      end
      d.check('output kept its last good answer') { window(app).output_row.text == '255' }
      d.shot('04-invalid')
    end

    d.step('switching to decimal in, hexadecimal out') do
      window(app).input_row.entry.text = ''
      window(app).input_row.dropdown.selected = 2
      window(app).output_row.dropdown.selected = 3
      window(app).input_row.entry.text = '1201'
    end

    d.step('decimal 1201 is hex 4B1') do
      d.check('output reads 4B1') { window(app).output_row.text == '4B1' }
      d.check('bit counters hidden away from binary') do
        !window(app).input_row.bit_button.visible? && !window(app).output_row.bit_button.visible?
      end
      d.shot('05-decimal-to-hex')
    end

    d.step('lower case hex is normalised upwards') do
      window(app).input_row.dropdown.selected = 3
      window(app).output_row.dropdown.selected = 2
      window(app).input_row.entry.text = 'ff'
    end

    d.step('the entry now reads FF') do
      d.check('input upper cased') { window(app).input_row.text == 'FF' }
      d.check('output reads 255') { window(app).output_row.text == '255' }
      d.shot('06-upper-cased')
    end

    d.step('the Other base reveals the spin button') do
      window(app).input_row.dropdown.selected = 4
    end

    d.step('base 2 to 36 is selectable by hand') do
      d.check('spin is visible') { window(app).input_row.spin.visible? }
      d.check('spin starts at base 2') { window(app).input_row.base == 2 }
      window(app).input_row.spin.value = 36
    end

    d.step('base 36 converts') do
      d.shot('07-other-base')
      window(app).input_row.entry.text = 'z'
    end

    d.step('z is 35') do
      d.check('output reads 35') { window(app).output_row.text == '35' }
      d.shot('08-base-36')
    end

    # --- base-prefixed literals, at the window rather than the Converter unit
    # --- (test-parity gap 20's second coverage hole: only Converter-unit
    # tests pinned 0b11/0o17/0x1F before this).

    d.step('binary in, decimal out, for a 0b-prefixed literal') do
      window(app).input_row.entry.text = ''
      window(app).input_row.dropdown.selected = 0
      window(app).output_row.dropdown.selected = 2
      window(app).input_row.entry.text = '0b11'
    end

    d.step('0b11 converts rather than flagging') do
      d.check('output reads 3') { window(app).output_row.text == '3' }
      d.check('no error styling on the input') do
        !window(app).input_row.entry.css_classes.include?('error')
      end
      d.shot('22a-0b-prefix')
    end

    d.step('octal in, decimal out, for a 0o-prefixed literal') do
      window(app).input_row.entry.text = ''
      window(app).input_row.dropdown.selected = 1
      window(app).input_row.entry.text = '0o17'
    end

    d.step('0o17 converts rather than flagging') do
      d.check('output reads 15') { window(app).output_row.text == '15' }
      d.check('no error styling on the input') do
        !window(app).input_row.entry.css_classes.include?('error')
      end
      d.shot('22b-0o-prefix')
    end

    d.step('hexadecimal in, decimal out, for a 0x-prefixed literal') do
      window(app).input_row.entry.text = ''
      window(app).input_row.dropdown.selected = 3
      window(app).input_row.entry.text = '0x1F'
    end

    d.step('0x1F converts rather than flagging') do
      d.check('output reads 31') { window(app).output_row.text == '31' }
      d.check('no error styling on the input') do
        !window(app).input_row.entry.css_classes.include?('error')
      end
      d.shot('22c-0x-prefix')
    end

    d.step('back to the Other base the window had before this detour') do
      window(app).input_row.entry.text = ''
      window(app).input_row.dropdown.selected = 4
    end

    d.step('closing saves the chosen bases') do
      window(app).on_close
      d.check('input base persisted') { Settings.new['input-base'] == 4 }
      d.check('output base persisted') { Settings.new['output-base'] == 2 }
    end

    d.step('the about dialog opens') do
      app.activate_action('about')
    end

    d.step('about is on screen') do
      SEEN[:about] = app.active_window.visible_dialog
      d.check('a dialog is showing') { !SEEN[:about].nil? }
      d.check('it names the release the notes are for') do
        SEEN[:about].release_notes_version == BinaryApp::VERSION
      end
      d.check('it carries the 5.4 release notes') do
        SEEN[:about].release_notes.include?('Binary 5.4 is a small update')
      end
      d.check('the notes are the metainfo markup, list and all') do
        SEEN[:about].release_notes.include?("<li>Binary now uses the system's monospace font by default</li>")
      end
      # new_from_appdata does not set `comments`, so the port does not either:
      # upstream's About dialog shows no description paragraph under the app
      # name, and neither does this one.
      d.check('and no description paragraph upstream would not show') do
        SEEN[:about].comments.nil? || SEEN[:about].comments.empty?
      end
      d.shot('09-about')
      app.active_window.visible_dialog&.close
    end

    # Upstream builds a new Adw.AboutDialog on every activation (src/main.py:70)
    # and the port does the same, so reopening is a second object rather than a
    # closed one shown again.
    d.step('about reopens after being closed') do
      app.activate_action('about')
    end

    d.step('about is on screen again') do
      d.check('a dialog is showing') { !app.active_window.visible_dialog.nil? }
      d.check('it is a fresh dialog, not the closed one') do
        !app.active_window.visible_dialog.equal?(SEEN[:about])
      end
      app.active_window.visible_dialog&.close
    end

    d.step('the shortcuts dialog opens') do
      app.activate_action('shortcuts')
    end

    d.step('shortcuts is on screen') do
      SEEN[:shortcuts] = app.active_window.visible_dialog
      d.check('a dialog is showing') { !SEEN[:shortcuts].nil? }
      d.shot('10-shortcuts')
      app.active_window.visible_dialog&.close
    end

    d.step('shortcuts reopens after being closed') do
      app.activate_action('shortcuts')
    end

    # A memoized dialog is one object presented twice: closed once, it is a
    # widget with no parent being shown again, and on a second window it is a
    # dialog whose root is the window it was first opened from. Every dialog
    # here is built per activation, and this is the check that says so.
    d.step('shortcuts is a fresh dialog') do
      d.check('a dialog is showing') { !app.active_window.visible_dialog.nil? }
      d.check('it is not the closed one') do
        !app.active_window.visible_dialog.equal?(SEEN[:shortcuts])
      end
      app.active_window.visible_dialog&.close
    end

    d.step('the preferences dialog opens') do
      app.activate_action('preferences')
    end

    d.step('preferences is on screen') do
      SEEN[:preferences] = app.active_window.visible_dialog
      d.check('a dialog is showing') { !app.active_window.visible_dialog.nil? }
      d.check('it opens at upstream\'s 400x306') do
        app.active_window.visible_dialog.then do |dialog|
          dialog.content_width == 400 && dialog.content_height == 306
        end
      end
      d.check('and refuses to go under 200 high') do
        app.active_window.visible_dialog.size_request == [-1, 200]
      end
      d.shot('11-preferences')
      app.active_window.visible_dialog&.close
    end

    d.step('preferences reopens after being closed') do
      app.activate_action('preferences')
    end

    d.step('preferences is a fresh dialog') do
      d.check('a dialog is showing') { !app.active_window.visible_dialog.nil? }
      d.check('it is not the closed one') do
        !app.active_window.visible_dialog.equal?(SEEN[:preferences])
      end
      app.active_window.visible_dialog&.close
    end

    d.step('a second window opens') do
      app.activate_action('new-window')
    end

    d.step('there are two windows') do
      d.check('two toplevels') { app.app.windows.length == 2 }
      d.shot('12-second-window')
    end

    # `binary --new-window` on a second invocation never reaches a
    # command-line signal — the port carries upstream's DEFAULT_FLAGS, so
    # there is none. It travels as the app.new-window action, which
    # #forward_new_window activates on the instance already running; in
    # process that is this.
    d.step('the --new-window flag opens another') do
      app.activate_action('new-window')
    end

    d.step('there are three windows') do
      d.check('three toplevels') { app.app.windows.length == 3 }
    end

    # A bare invocation routes through app.activate, and the driver starts its
    # step loop on that signal — calling it here would run every step a second
    # time. What activate does is present_window, so that is what is driven.
    d.step('a bare invocation just presents what is there') do
      app.present_window
    end

    d.step('still three windows') do
      d.check('no fourth window') { app.app.windows.length == 3 }
    end

    d.step('about opens on the second window too') do
      app.activate_action('about')
    end

    d.step('the dialog followed the new window') do
      d.check('a dialog is showing') { !app.active_window.visible_dialog.nil? }
      d.check('it is not an instance shown on an earlier window') do
        !app.active_window.visible_dialog.equal?(SEEN[:about])
      end
      d.check('its parent is the window it was opened from') do
        app.active_window.visible_dialog.root.equal?(app.active_window)
      end
      d.shot('13-about-second-window')
      app.active_window.visible_dialog&.close
    end

    # --new-window is a GLib main option, so GLib itself prints it in the help
    # and rejects anything it was not told about.
    d.step('--help documents the flag') do
      SEEN[:help] = `#{RbConfig.ruby} #{File.expand_path('../exe/binary', __dir__)} --help 2>&1`
      SEEN[:help_status] = $CHILD_STATUS.exitstatus
      d.check('help mentions --new-window') { SEEN[:help].include?('--new-window') }
      d.check('help gives the short name too') { SEEN[:help].include?('-w') }
      d.check('and asking for it succeeds') { SEEN[:help_status].zero? }
    end

    d.step('an option nobody declared is rejected') do
      SEEN[:nonsense] = `#{RbConfig.ruby} #{File.expand_path('../exe/binary', __dir__)} --nonsense 2>&1`
      SEEN[:nonsense_status] = $CHILD_STATUS.exitstatus
      d.check('GLib names the unknown option') { SEEN[:nonsense].include?('--nonsense') }
      d.check('and says so') { SEEN[:nonsense].downcase.include?('unknown option') }
      # g_application_run returns 1 here, and exe/binary exits with it, the way
      # upstream's `sys.exit(main.main())` does — a rejected option that left
      # the process reporting success is a failure no caller could see.
      d.check('and the process fails') { SEEN[:nonsense_status] == 1 }
    end

    # Upstream passes Gio.ApplicationFlags.DEFAULT_FLAGS (src/main.py:34), and
    # a GApplication with neither HANDLES_OPEN nor HANDLES_COMMAND_LINE refuses
    # a non-option argument outright. That refusal is the reason the port
    # carries the same flags instead of HANDLES_COMMAND_LINE: with the latter
    # `binary nonsense-argument` opened a window and stayed up.
    d.step('a non-option argument is refused the way upstream refuses it') do
      d.check('the flags are upstream\'s') do
        app.app.flags == Gio::ApplicationFlags::DEFAULT_FLAGS
      end
      # Its own session bus, the way the high-contrast child gets one below:
      # this driver is itself a registered instance of the app id, and a second
      # invocation that finds itself remote hands the argument to the running
      # instance instead of being refused locally. What is being measured here
      # is the refusal a user gets when nothing else is running.
      SEEN[:argument] =
        `dbus-run-session -- #{RbConfig.ruby} \
         #{File.expand_path('../exe/binary', __dir__)} nonsense-argument 2>&1`
      SEEN[:argument_status] = $CHILD_STATUS.exitstatus
      # Measured, not remembered: glib 2.86 in this shell prints
      # "GLib-GIO-CRITICAL **: This application can not open files." and
      # g_application_run returns 1. Upstream's Python reaches the same GLib
      # with the same flags, so it prints the same line.
      d.check('GLib refuses to open it as a file') do
        SEEN[:argument].include?('can not open files')
      end
      d.check('and the process fails rather than opening a window') do
        SEEN[:argument_status] == 1
      end
    end

    # The local-options path upstream takes: not remote here, so it declines
    # (-1) and leaves the normal startup to open the window.
    d.step('the local-options handler declines when it is the only instance') do
      d.check('new-window in the dict defers to startup') do
        app.handle_local_options(new_window_options) == -1
      end
      d.check('an empty dict declines too') do
        app.handle_local_options(GLib::VariantDict.new(nil)) == -1
      end
    end

    # The gem's require entry point has to reach the real application, not a
    # second one with its own app id.
    d.step('require "binary" loads the port') do
      require 'binary'
      d.check('BinaryApp is defined') { defined?(BinaryApp) == 'constant' }
      d.check('under upstream\'s app id') { BinaryApp::APP_ID == 'io.github.fizzyizzy05.binary' }
      d.check('and no scaffold application survives') { !defined?(Binary::Application) }
    end

    # --- the window's own chrome -------------------------------------------

    d.step('the window is sized and shaped the way src/window.blp says') do
      d.check('its title is Binary') { window(app).window.title == 'Binary' }
      d.check('it opens at 360x390') { window(app).window.default_size == [360, 390] }
      d.check('and refuses to go under 360x294') { window(app).window.size_request == [360, 294] }
      d.check('the header bar hides its title') { !window(app).header_bar.show_title? }
      d.check('the toolbar view holds the window handle') do
        window(app).toolbar_view.content.equal?(window(app).window_handle)
      end
      d.check('the handle holds the clamp') do
        window(app).window_handle.child.equal?(window(app).clamp)
      end
      d.check('the clamp clamps at 600') { window(app).clamp.maximum_size == 600 }
      d.check('and tightens at 1000') { window(app).clamp.tightening_threshold == 1000 }
      d.check('the clamp holds the content box') do
        window(app).clamp.child.equal?(window(app).content_box)
      end
      d.check('the content box carries the blueprint\'s margins') do
        window(app).content_box.then do |box|
          [box.margin_start, box.margin_end, box.margin_top, box.margin_bottom] == [30, 30, 30, 60]
        end
      end
      d.check('the arrow box is the typing label') do
        window(app).arrow_box.css_classes.include?('typing-label')
      end
      d.check('the arrow is the icon upstream bundles') do
        window(app).arrow_image.icon_name == 'vertical-arrows-symbolic'
      end
      d.check('the icon theme resolves it, so #install_icons found the SVG') do
        Gtk::IconTheme.get_for_display(Gdk::Display.default).has_icon?('vertical-arrows-symbolic')
      end
      d.check('and the menu icon it does not ship') do
        Gtk::IconTheme.get_for_display(Gdk::Display.default).has_icon?('open-menu-symbolic')
      end
    end

    d.step('both halves are the entries src/window.blp declares') do
      [window(app).input_row, window(app).output_row].each_with_index do |row, index|
        d.check("half #{index} shows the placeholder") do
          row.entry.placeholder_text == 'Enter numbers'
        end
        d.check("half #{index} has undo turned off") { !row.entry.enable_undo? }
        d.check("half #{index} offers upstream's five bases") do
          row.dropdown.model.then do |model|
            (0...model.n_items).map { |i| model.get_item(i).string } ==
              ['Binary', 'Octal', 'Decimal', 'Hexadecimal', 'Other']
          end
        end
        d.check("half #{index} spins from base 2 to 36, snapping") do
          row.spin.then do |spin|
            spin.adjustment.lower == 2.0 && spin.adjustment.upper == 36.0 && spin.snap_to_ticks?
          end
        end
        d.check("half #{index} has a flat classed bit button") do
          row.bit_button.css_classes.then do |classes|
            classes.include?('bitLbl') && classes.include?('flat')
          end
        end
        d.check("half #{index} has the flat dropdown") do
          row.dropdown.css_classes.include?('flat-dropdown')
        end
      end
      d.check('the input half is tooltipped as the input base') do
        window(app).input_row.dropdown.tooltip_text == 'Input Base'
      end
      d.check('and the output half as the output base') do
        window(app).output_row.dropdown.tooltip_text == 'Output Base'
      end
      # src/window.py:48 asks gettext for this and never reads it. The port is
      # dead in the same way, so the msgid stays in all 32 catalogues.
      d.check('the dead "bits" msgid is still asked for') { ConversionRow::BITS_TEXT.call == 'bits' }
    end

    d.step('presenting the window puts the cursor in the input entry') do
      window(app).present
    end

    d.step('the focus is where upstream\'s grab_focus puts it') do
      d.check('the focused widget is inside the input entry') do
        window(app).window.focus_widget
          .get_ancestor(Gtk::Entry.gtype)
          .equal?(window(app).input_row.entry)
      end
    end

    # --- the primary menu ---------------------------------------------------

    d.step('the menu button is the window\'s primary one') do
      d.check('it is marked primary') { window(app).menu_button.primary? }
      d.check('it shows the hamburger') do
        window(app).menu_button.icon_name == 'open-menu-symbolic'
      end
      d.check('and it is tooltipped') { window(app).menu_button.tooltip_text == 'Main Menu' }
      window(app).menu_button.popup
    end

    d.step('the menu is open and holds upstream\'s two sections') do
      d.check('a menu popover came up') { window(app).menu_button.popover.is_a?(Gtk::PopoverMenu) }
      d.check('and it is on screen') { window(app).menu_button.popover.visible? }
      d.check('the model is two sections') { window(app).primary_menu.n_items == 2 }
      d.check('the first offers New Window') do
        window(app).window_section.then do |section|
          section.n_items == 1 &&
            section.get_item_attribute_value(0, 'label', nil) == 'New Window' &&
            section.get_item_attribute_value(0, 'action', nil) == 'app.new-window'
        end
      end
      d.check('the second offers the shortcuts and about items') do
        window(app).app_section.then do |section|
          section.n_items == 2 &&
            section.get_item_attribute_value(0, 'label', nil) == '_Keyboard Shortcuts' &&
            section.get_item_attribute_value(0, 'action', nil) == 'app.shortcuts' &&
            section.get_item_attribute_value(1, 'label', nil) == '_About Binary' &&
            section.get_item_attribute_value(1, 'action', nil) == 'app.about'
        end
      end
      d.shot('14-primary-menu')
      window(app).menu_button.popdown
    end

    # --- actions and accelerators -------------------------------------------

    d.step('every action is registered with the accelerator upstream gives it') do
      BinaryApp::ACTIONS.each do |name, accels|
        d.check("app.#{name} is registered") { !app.app.lookup_action(name).nil? }
        d.check("app.#{name} is enabled") { app.app.lookup_action(name).enabled? }
        d.check("app.#{name} is bound to #{accels.empty? ? 'nothing' : accels.join(', ')}") do
          app.app.get_accels_for_action("app.#{name}") ==
            accels.map { |accel| accel.sub('<primary>', '<Control>') }
        end
      end
      d.check('and nothing the menu points at is a dead action') do
        ['app.new-window', 'app.shortcuts', 'app.about'].all? do |action|
          !app.app.lookup_action(action.delete_prefix('app.')).nil?
        end
      end
    end

    # --- the bit popover ----------------------------------------------------

    d.step('back to binary in, decimal out, with something to count') do
      window(app).input_row.entry.text = ''
      window(app).input_row.dropdown.selected = 0
      window(app).output_row.dropdown.selected = 2
      window(app).input_row.entry.text = '1010'
    end

    d.step('the bit button counts the digits and opens') do
      d.check('output reads 10') { window(app).output_row.text == '10' }
      d.check('the bit button counts four') { window(app).input_row.bit_button.label == '4 bits' }
      d.check('it is sensitive with digits to count') { window(app).input_row.bit_button.sensitive? }
      d.check('and it is visible on the binary side') { window(app).input_row.bit_button.visible? }
      window(app).input_row.bit_button.popup
    end

    d.step('the popover shows the place values behind the answer') do
      d.check('the popover is on screen') { window(app).input_row.bit_popover.visible? }
      d.check('it is the button\'s own popover') do
        window(app).input_row.bit_button.popover.equal?(window(app).input_row.bit_popover)
      end
      d.check('it breaks the number down') do
        window(app).input_row.bits_label.label == '8 + 2 = 1010'
      end
      d.check('and it wraps rather than stretching') do
        window(app).input_row.bits_label.then do |label|
          label.wrap? && label.max_width_chars == 30
        end
      end
      d.shot('15-bit-popover')
      window(app).input_row.bit_button.popdown
    end

    d.step('the output half has a popover of its own') do
      window(app).output_row.dropdown.selected = 0
      window(app).input_row.dropdown.selected = 2
      window(app).input_row.entry.text = '10'
    end

    d.step('the output side counts its own bits') do
      d.check('output reads 1010') { window(app).output_row.text == '1010' }
      d.check('its bit button is visible now it is the binary side') do
        window(app).output_row.bit_button.visible?
      end
      d.check('and the input side\'s is hidden') { !window(app).input_row.bit_button.visible? }
      d.check('the output bit button counts its four digits') do
        window(app).output_row.bit_button.label == '4 bits'
      end
      window(app).output_row.bit_button.popup
    end

    d.step('the output popover is a second popover, not the input one') do
      d.check('it is on screen') { window(app).output_row.bit_popover.visible? }
      d.check('it is not the input half\'s popover') do
        !window(app).output_row.bit_popover.equal?(window(app).input_row.bit_popover)
      end
      d.check('and it breaks down the output number') do
        window(app).output_row.bits_label.label == '8 + 2 = 1010'
      end
      d.shot('15b-output-bit-popover')
      window(app).output_row.bit_button.popdown
    end

    # --- the empty state ----------------------------------------------------

    d.step('emptying the input empties the whole window') do
      window(app).input_row.entry.text = ''
    end

    d.step('the window is back in the state it launched in') do
      d.check('the input is empty') { window(app).input_row.text.empty? }
      d.check('the output is empty too') { window(app).output_row.text.empty? }
      d.check('neither entry is monospaced') do
        [window(app).input_row, window(app).output_row].none? do |row|
          row.entry.css_classes.include?('monospace')
        end
      end
      d.check('neither entry is flagged') do
        [window(app).input_row, window(app).output_row].none? do |row|
          row.entry.css_classes.include?('error')
        end
      end
      d.check('no tooltip is left over') do
        [window(app).input_row, window(app).output_row].all? do |row|
          row.entry.tooltip_text.nil?
        end
      end
      d.check('and both bit buttons went insensitive') do
        [window(app).input_row, window(app).output_row].none? do |row|
          row.bit_button.sensitive?
        end
      end
      d.shot('16-empty-again')
    end

    # --- the error states ---------------------------------------------------

    d.step('a space makes the input invalid') do
      window(app).input_row.entry.text = '1 0'
    end

    d.step('the space is flagged on the input side only') do
      d.check('the input is flagged') { window(app).input_row.entry.css_classes.include?('error') }
      d.check('with the invalid-input tooltip') do
        window(app).input_row.entry.tooltip_text == 'Invalid input'
      end
      d.check('the output side is not tooltipped') { window(app).output_row.entry.tooltip_text.nil? }
      d.shot('17-space')
    end

    d.step('a leading minus is invalid as well') do
      window(app).input_row.entry.text = '-1'
    end

    d.step('the minus is flagged') do
      d.check('the input is flagged') { window(app).input_row.entry.css_classes.include?('error') }
      d.check('with the invalid-input tooltip') do
        window(app).input_row.entry.tooltip_text == 'Invalid input'
      end
      d.shot('18-minus')
    end

    d.step('a good answer, to append a plus sign to') do
      window(app).input_row.entry.text = '1010'
    end

    # Upstream's get_answer raises on "+" and its caller never finishes, so
    # nothing the user can see changes. The port reproduces that, and this is
    # the check that says the window really does nothing rather than something
    # subtly different.
    d.step('appending the plus takes upstream\'s abort path') do
      SEEN[:before_plus] = [
        window(app).output_row.text,
        window(app).input_row.bit_button.label,
        window(app).input_row.entry.css_classes.include?('error'),
        window(app).input_row.bits_label.label,
      ]
      window(app).input_row.entry.buffer.insert_text(4, '+', 1)
    end

    d.step('the window is exactly as it was before the plus') do
      d.check('the input carries the plus') { window(app).input_row.text == '1010+' }
      d.check('the output kept its answer') { window(app).output_row.text == SEEN[:before_plus][0] }
      d.check('the bit count was not touched') do
        window(app).input_row.bit_button.label == SEEN[:before_plus][1]
      end
      d.check('the breakdown was not touched either') do
        window(app).input_row.bits_label.label == SEEN[:before_plus][3]
      end
      d.check('and no error was raised against the input') do
        window(app).input_row.entry.css_classes.include?('error') == SEEN[:before_plus][2]
      end
      d.shot('19-plus-aborts')
    end

    d.step('both halves in decimal, with something invalid in decimal') do
      window(app).input_row.entry.text = ''
      window(app).input_row.dropdown.selected = 2
      window(app).output_row.dropdown.selected = 2
      window(app).input_row.entry.text = 'ZZ'
    end

    d.step('equal bases flag both entries and echo the text across') do
      d.check('the input is flagged') { window(app).input_row.entry.css_classes.include?('error') }
      d.check('the output is flagged too') { window(app).output_row.entry.css_classes.include?('error') }
      d.check('both are tooltipped') do
        [window(app).input_row, window(app).output_row].all? do |row|
          row.entry.tooltip_text == 'Invalid input'
        end
      end
      d.check('and the text was echoed across unconverted') { window(app).output_row.text == 'ZZ' }
      d.shot('20-char-dual')
    end

    d.step('a fraction, still with both halves in decimal') do
      window(app).input_row.entry.text = '10.1'
    end

    d.step('matching bases echo the fraction through untouched') do
      d.check('the output echoes it') { window(app).output_row.text == '10.1' }
      d.check('the input is not flagged') do
        !window(app).input_row.entry.css_classes.include?('error')
      end
      d.check('nor is the output') do
        !window(app).output_row.entry.css_classes.include?('error')
      end
    end

    d.step('the same fraction across two different bases') do
      window(app).output_row.dropdown.selected = 3
      window(app).input_row.entry.text = '10.1'
    end

    # src/lib/get_answer.py:84 leaves the fractional case uncalculated and
    # falls through to the invalid-input branch. Upstream's debt, reproduced.
    d.step('upstream\'s uncalculated fractional case shows as invalid input') do
      d.check('the input is flagged') { window(app).input_row.entry.css_classes.include?('error') }
      d.check('with the invalid-input tooltip') do
        window(app).input_row.entry.tooltip_text == 'Invalid input'
      end
      d.shot('21-fraction')
    end

    d.step('something invalid typed into the output entry instead') do
      window(app).input_row.entry.text = ''
      window(app).input_row.dropdown.selected = 0
      window(app).output_row.dropdown.selected = 2
      window(app).output_row.entry.buffer.insert_text(0, 'Z', 1)
    end

    d.step('the backwards handler flags the output and clears the input of blame') do
      d.check('the output is flagged') { window(app).output_row.entry.css_classes.include?('error') }
      d.check('with the invalid-input tooltip') do
        window(app).output_row.entry.tooltip_text == 'Invalid input'
      end
      d.check('the input is not flagged') do
        !window(app).input_row.entry.css_classes.include?('error')
      end
      d.check('and its tooltip is cleared') { window(app).input_row.entry.tooltip_text.nil? }
      d.shot('22-output-invalid')
    end

    # --- the stylesheets ----------------------------------------------------

    # A stylesheet cannot be read back out of a Gtk::CssProvider — the bindings
    # have no #to_string — and no widget will say what its computed opacity is.
    # What a widget will say is how big it wants to be, and .bitLbl sets a
    # font-size, so a label's width is a measurement that only comes out right
    # while the sheet is actually on the display.
    d.step('the base stylesheet is live on the display') do
      SEEN[:plain] = Gtk::Label.new('6 bits')
      SEEN[:classed] = Gtk::Label.new('6 bits').tap { |label| label.add_css_class('bitLbl') }
      window(app).content_box.append(SEEN[:plain])
      window(app).content_box.append(SEEN[:classed])
      SEEN[:plain_width] = SEEN[:plain].preferred_size.first.width
      d.check('.bitLbl shrinks the label, as the sheet says it should') do
        SEEN[:classed].preferred_size.first.width < SEEN[:plain_width]
      end
      d.check('the sheet carries all three of src/style.css\'s rules') do
        ['.bitLbl', '.flat-dropdown', '.typing-label'].all? do |rule|
          BinaryApp::STYLE.include?(rule)
        end
      end
    end

    d.step('the sheet comes off the display') do
      Gtk::StyleContext.remove_provider_for_display(app.display, app.style_provider)
    end

    d.step('and the label springs back to its unstyled size') do
      d.check('.bitLbl no longer shrinks it') do
        SEEN[:classed].preferred_size.first.width == SEEN[:plain_width]
      end
      Gtk::StyleContext.add_provider_for_display(
        app.display,
        app.style_provider,
        Gtk::StyleProvider::PRIORITY_APPLICATION,
      )
      window(app).content_box.remove(SEEN[:plain])
      window(app).content_box.remove(SEEN[:classed])
    end

    d.step('the high-contrast sheet is the one src/style-hc.css ships') do
      d.check('it lifts the typing label out of the base opacity') do
        BinaryApp::HIGH_CONTRAST_STYLE.include?('opacity: 0.75')
      end
      d.check('and sits above the base sheet, so it wins') do
        BinaryApp::HIGH_CONTRAST_PRIORITY > Gtk::StyleProvider::PRIORITY_APPLICATION
      end
      d.check('high contrast is off in this run') { !app.style_manager.high_contrast? }
      d.check('so syncing takes the remove branch and the window survives it') do
        app.sync_high_contrast
        window(app).arrow_box.css_classes.include?('typing-label')
      end
    end

    # The add branch needs AdwStyleManager:high-contrast to be on, and
    # libadwaita settles that at startup from an environment variable, so it
    # cannot be reached from in here. test/high_contrast_check.rb is the same
    # harness with ADW_DEBUG_HIGH_CONTRAST=1 set before Adwaita.init.
    # dbus-run-session, because GApplication will not run without a session bus
    # and this process already holds io.github.fizzyizzy05.binary on the one it
    # was given — a second instance on the same bus goes remote, its activate
    # never fires, and the child reports DRIVE OK having run no checks at all.
    d.step('the add branch is driven in a process of its own') do
      SEEN[:hc_command] = "dbus-run-session -- #{RbConfig.ruby} " \
                          "#{File.expand_path('high_contrast_check.rb', __dir__)} 2>&1"
      SEEN[:hc] = `#{SEEN[:hc_command]}`
      SEEN[:hc_status] = $CHILD_STATUS.exitstatus
      d.check('the child came up in high contrast') do
        SEEN[:hc].include?('ok   high contrast is on')
      end
      d.check('its window built and still converted') { SEEN[:hc].include?('ok   output reads 10') }
      # Named explicitly, because a run that registered no checks at all also
      # prints DRIVE OK, and that is exactly what a child gone remote does.
      d.check('it ran all six of its checks') { SEEN[:hc].include?('6 of 6 checks passed') }
      d.check('and it ended green') do
        SEEN[:hc].include?('DRIVE OK') && SEEN[:hc_status].zero?
      end
    end

    # --- the installed-gem failure path -------------------------------------

    # component-parity gap 3's failure path, driven rather than just asserted
    # by inspection (test-parity gap 20's first coverage hole): an installed
    # gem that `rake build` never compiled data/schemas/gschemas.compiled
    # into has no schema for Gio::Settings to open, and g_error aborts the
    # process outright — there is no exception a caller could rescue, so the
    # only way to see it is to run the binary and watch it die. The compiled
    # schema is moved aside, GSETTINGS_SCHEMA_DIR is unset for the child only,
    # and the child gets its own session bus, the way the other two subprocess
    # probes above do.
    d.step('the compiled schema is moved out of the way') do
      SEEN[:compiled_schema] = File.expand_path('../data/schemas/gschemas.compiled', __dir__)
      SEEN[:schema_moved_to] = "#{SEEN[:compiled_schema]}.moved-for-drive"
      SEEN[:schema_was_there] = File.exist?(SEEN[:compiled_schema])
      if SEEN[:schema_was_there]
        FileUtils.mv(SEEN[:compiled_schema], SEEN[:schema_moved_to])
      end
    end

    d.step('a gem installed with no compiled schema aborts rather than opening') do
      SEEN[:schema_missing_out], SEEN[:schema_missing_status] =
        Open3.capture2e(
          {'GSETTINGS_SCHEMA_DIR' => nil},
          'dbus-run-session',
          '--',
          RbConfig.ruby,
          File.expand_path('../exe/binary', __dir__),
        )
    end

    d.step('the compiled schema is put back') do
      if SEEN[:schema_was_there]
        FileUtils.mv(SEEN[:schema_moved_to], SEEN[:compiled_schema])
      end
    end

    d.step('the abort is the one Gio::Settings.new has no exception for') do
      d.check('the schema really was there to move') { SEEN[:schema_was_there] }
      d.check('the process did not exit cleanly') { !SEEN[:schema_missing_status].success? }
      d.check('GLib named the missing schema, not some other failure') do
        SEEN[:schema_missing_out].downcase.include?('schema')
      end
    end

    # --- the dialogs' own contents ------------------------------------------

    d.step('the preferences dialog is the empty page src/preferences.blp has') do
      PreferencesDialog.new.then do |prefs|
        prefs.build
        d.check('it is titled Preferences') { prefs.dialog.title == 'Preferences' }
        d.check('it holds one preferences page') { prefs.page.is_a?(Adwaita::PreferencesPage) }
        d.check('and #add really parented it into the dialog') do
          prefs.page.parent.is_a?(Adwaita::ViewStack)
        end
        # src/preferences.blp gives the page no groups and no rows, and nothing
        # in src/preferences.py adds any.
        d.check('the page has no groups, exactly as upstream') { prefs.page.get_group(0).nil? }
      end
    end

    d.step('the shortcuts dialog is the four items src/shortcuts-dialog.blp has') do
      ShortcutsDialog.new.then do |shortcuts|
        shortcuts.build
        d.check('it is an AdwShortcutsDialog') { shortcuts.dialog.is_a?(Adwaita::ShortcutsDialog) }
        d.check('its one section is the General one') { shortcuts.general_section.title == 'General' }
        [
          ['New Window', 'app.new-window'],
          ['Close Window', 'app.close-window'],
          ['Show Shortcuts', 'app.shortcuts'],
          ['Quit', 'app.quit'],
        ].each do |title, action|
          shortcuts.item(title, action).then do |shortcut|
            d.check("#{title} carries its title") { shortcut.title == title }
            d.check("#{title} names #{action}") { shortcut.action_name == action }
            # Upstream's own blueprint points at app.shortcuts, which
            # src/main.py never creates. Every action this dialog names has to
            # be one the application really has, or the row is dead.
            d.check("#{action} is an action the application has") do
              !app.app.lookup_action(action.delete_prefix('app.')).nil?
            end
          end
        end
      end
    end

    # --- the data files the shell reads -------------------------------------

    # Nothing in the running app reads these, which is exactly why they are
    # worth checking against it: the desktop entry's action and the service
    # file's name are promises about what the application will answer to.
    d.step('the desktop entry promises what the application delivers') do
      File.read(File.expand_path('../data/io.github.fizzyizzy05.binary.desktop.in', __dir__))
        .then do |desktop|
          d.check('it declares the new-window action') { desktop.include?('Actions=new-window;') }
          d.check('and launches it with the flag GLib accepted') do
            desktop.include?('Exec=binary --new-window')
          end
          d.check('which is an action the application really has') do
            !app.app.lookup_action('new-window').nil?
          end
          d.check('it is D-Bus activatable, as the service file assumes') do
            desktop.include?('DBusActivatable=true')
          end
          # The port sets no per-window icon_name — #app does
          # Gtk::Window.set_default_icon_name, so every window inherits it and
          # the property itself stays nil.
          d.check('and its icon is the default every window inherits') do
            desktop.include?("Icon=#{BinaryApp::APP_ID}") &&
              Gtk::Window.default_icon_name == BinaryApp::APP_ID
          end
        end
    end

    d.step('the D-Bus service file names the application the app registers as') do
      File.read(File.expand_path('../data/io.github.fizzyizzy05.binary.service.in', __dir__))
        .then do |service|
          d.check('the bus name is the app id') { service.include?("Name=#{BinaryApp::APP_ID}") }
          d.check('and it starts the app in service mode') do
            service.include?('--gapplication-service')
          end
          # GLib keeps this one in its own option group, so it shows under
          # --help-all rather than --help.
          d.check('which is a flag GLib itself documents and handles') do
            `#{RbConfig.ruby} #{File.expand_path('../exe/binary', __dir__)} --help-all 2>&1`
              .include?('--gapplication-service     Enter GApplication service mode')
          end
        end
    end

    # --- closing down -------------------------------------------------------

    d.step('close-window closes the window it was fired on') do
      SEEN[:windows_before_close] = app.app.windows.length
      app.activate_action('close-window')
    end

    d.step('there is one window fewer') do
      d.check('a window went away') do
        app.app.windows.length == SEEN[:windows_before_close] - 1
      end
      d.check('and there is still one left to work in') { !app.active_window.nil? }
    end

    # Fired last, because it ends the main loop. The step after it is the
    # assertion: if quit did nothing, that step runs and sets the flag, and the
    # shutdown handler — which runs before the driver reports — fails on it.
    d.step('quit ends the application') do
      app.app.signal_connect('shutdown') do
        d.check('quit reached shutdown') { true }
        d.check('and no step ran after it') { !SEEN[:after_quit] }
      end
      app.activate_action('quit')
    end

    d.step('this step must never run') do
      SEEN[:after_quit] = true
    end
  end
end
