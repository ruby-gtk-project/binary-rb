# frozen_string_literal: true

# The same window under a translated locale. Assertions prove the catalogues
# reach the widgets; the screenshot proves the result still fits in the layout,
# which is the half a string comparison cannot tell you.

require_relative 'environment'

ENV['LC_ALL'] = 'en_GB.UTF-8'
ENV['LANGUAGE'] = 'de'

require_relative '../lib/main'
require_relative 'gtk_driver'

def window(app)
  app.windows.last
end

BinaryApp.new.then do |app|
  GtkDriver.drive(app, shots: 'tmp/shots') do |d, _|
    d.window { app.active_window }

    d.step('the window comes up in German') do
      d.check('the base names are translated') do
        window(app).input_row.dropdown.model.get_item(1).string == 'Oktal'
      end
      d.check('the base names upstream leaves alone stay English') do
        window(app).input_row.dropdown.model.get_item(0).string == 'Binary'
      end
      d.check('the base tooltip is translated') do
        window(app).input_row.dropdown.tooltip_text == 'Basis Eingabe'
      end
      d.check('the menu button tooltip is translated') do
        window(app).menu_button.tooltip_text == 'Hauptmenü'
      end
      d.check('the placeholder is translated') do
        window(app).input_row.entry.placeholder_text == 'Zahl eingeben'
      end
    end

    d.step('type something binary') do
      window(app).input_row.entry.text = '101010'
    end

    d.step('the bit counter is translated and plural-correct') do
      d.check('reads 6 Bits') { window(app).input_row.bit_button.label == '6 Bits' }
      d.shot('20-german')
    end

    d.step('an invalid digit') do
      window(app).input_row.entry.buffer.insert_text(6, '2', 1)
    end

    d.step('the tooltip is translated') do
      d.check('reads Ungültige Eingabe') do
        window(app).input_row.entry.tooltip_text == 'Ungültige Eingabe'
      end
      d.shot('21-german-invalid')
    end

    d.step('the shortcuts dialog opens') do
      app.activate_action('shortcuts')
    end

    d.step('its section title came from the shortcut window context') do
      d.check('a dialog is showing') { !app.active_window.visible_dialog.nil? }
      d.shot('22-german-shortcuts')
      app.active_window.visible_dialog&.close
    end
  end
end
