# frozen_string_literal: true

# Drives the real window: types into the entries, switches bases, opens the
# menu dialogs, and writes screenshots to tmp/shots for eyeballing.

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir

require_relative '../lib/main'
require_relative 'gtk_driver'

# The window under test is the one the app most recently made.
def window(app)
  app.windows.last
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
      d.shot('01-empty')
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
      d.check('input base persisted') { Settings.new['input_base'] == 4 }
      d.check('output base persisted') { Settings.new['output_base'] == 2 }
    end

    d.step('the about dialog opens') do
      app.activate_action('about')
    end

    d.step('about is on screen') do
      d.check('a dialog is showing') { !app.active_window.visible_dialog.nil? }
      d.shot('09-about')
      app.active_window.visible_dialog&.close
    end

    # The dialogs are memoized, so reopening one has to work on an object that
    # has already been closed once — and on a window it was not first shown on.
    d.step('about reopens after being closed') do
      app.activate_action('about')
    end

    d.step('about is on screen again') do
      d.check('a dialog is showing') { !app.active_window.visible_dialog.nil? }
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

    d.step('about opens on the second window too') do
      app.activate_action('about')
    end

    d.step('the dialog followed the new window') do
      d.check('a dialog is showing') { !app.active_window.visible_dialog.nil? }
      d.shot('13-about-second-window')
    end
  end
end
