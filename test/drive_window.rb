# frozen_string_literal: true

# Drives the real window: types into the entries, switches bases, opens the
# menu dialogs, and writes screenshots to tmp/shots for eyeballing.

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
      d.check('the summary came across too') do
        SEEN[:about].comments.start_with?('A small and simple app')
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
      d.check('a dialog is showing') { !app.active_window.visible_dialog.nil? }
      d.shot('10-shortcuts')
      app.active_window.visible_dialog&.close
    end

    d.step('the preferences dialog opens') do
      app.activate_action('preferences')
    end

    d.step('preferences is on screen') do
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

    d.step('a second window opens') do
      app.activate_action('new-window')
    end

    d.step('there are two windows') do
      d.check('two toplevels') { app.app.windows.length == 2 }
      d.shot('12-second-window')
    end

    # `binary --new-window` reaches the running instance through the
    # command-line signal rather than through activate.
    d.step('the --new-window flag opens another') do
      app.handle_command_line(['binary', '--new-window'])
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
      d.check('help mentions --new-window') { SEEN[:help].include?('--new-window') }
      d.check('help gives the short name too') { SEEN[:help].include?('-w') }
    end

    d.step('an option nobody declared is rejected') do
      SEEN[:nonsense] = `#{RbConfig.ruby} #{File.expand_path('../exe/binary', __dir__)} --nonsense 2>&1`
      d.check('GLib names the unknown option') { SEEN[:nonsense].include?('--nonsense') }
      d.check('and says so') { SEEN[:nonsense].downcase.include?('unknown option') }
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
  end
end
