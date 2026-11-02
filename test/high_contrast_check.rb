# frozen_string_literal: true

# The high-contrast half of lib/main.rb's style keying, driven in a process of
# its own.
#
# AdwStyleManager:high-contrast is read-only — the Ruby bindings expose no
# `high_contrast=` at all — and libadwaita settles the value once at startup
# from the portal, so nothing inside a running process can turn it on. The one
# switch libadwaita offers is the ADW_DEBUG_HIGH_CONTRAST environment variable,
# and that has to be set before Adwaita.init, which is why this is a second
# process rather than another step in test/drive_window.rb. That script runs
# this one and reads what it prints.
#
#   nix develop --command xvfb-run -a ruby test/high_contrast_check.rb

ENV['ADW_DEBUG_HIGH_CONTRAST'] = '1'

require_relative 'environment'
require_relative '../lib/main'
require_relative 'gtk_driver'

BinaryApp.new.then do |app|
  GtkDriver.drive(app, shots: 'tmp/shots') do |d, _|
    d.window { app.active_window }

    d.step('the style manager comes up in high contrast') do
      d.check('high contrast is on') { app.style_manager.high_contrast? }
      d.check('the window still built') { !app.active_window.nil? }
      d.check('the typing label is still classed') do
        app.windows.last.arrow_box.css_classes.include?('typing-label')
      end
      d.shot('23-high-contrast')
    end

    # The sheet the add branch puts on the display only changes an opacity, and
    # an opacity is the one thing a widget cannot be asked about from Ruby. So
    # what is asserted is that the branch runs and leaves a working window
    # behind — and the screenshot above is the half that shows the result.
    d.step('the window still converts under the high-contrast sheet') do
      app.windows.last.input_row.entry.text = '1010'
    end

    d.step('the answer came out the same') do
      d.check('output reads 10') { app.windows.last.output_row.text == '10' }
      d.check('the bit count is still there') do
        app.windows.last.input_row.bit_button.label == '4 bits'
      end
      d.check('syncing again is idempotent') do
        app.sync_high_contrast
        app.style_manager.high_contrast?
      end
      d.shot('24-high-contrast-converted')
    end
  end
end
