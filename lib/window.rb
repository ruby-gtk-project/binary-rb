# frozen_string_literal: true

require 'adwaita'

require_relative 'conversion_row'
require_relative 'converter'

# The Binary window: two conversion rows that write into each other.
#
# Editing either entry recomputes the other. `@editable` is upstream's guard
# against the resulting ping-pong — the handler that is writing clears it, so
# the write it triggers is ignored rather than bouncing back.
class BinaryWindow
  def initialize(app:, settings:)
    @app = app
    @settings = settings
    @editable = false
  end

  def build
    window.tap do |win|
      win.content = toolbar_view
      win.signal_connect('close-request') do
        on_close
        false
      end

      toolbar_view.tap do |tv|
        tv.add_top_bar(header_bar)
        tv.content = window_handle

        header_bar.tap do |hb|
          hb.pack_start(menu_button)

          menu_button.menu_model = primary_menu
        end

        window_handle.tap do |wh|
          wh.child = clamp

          clamp.tap do |cl|
            cl.child = content_box

            content_box.tap do |box|
              box.append(input_row.build)
              box.append(arrow_box)
              box.append(output_row.build)

              arrow_box.append(arrow_image)
            end
          end
        end
      end
    end

    restore_bases
    window
  end

  def present
    window.present
    input_row.entry.grab_focus
  end

  # --- handlers ---------------------------------------------------------

  def input_handler
    @editable = false
    convert_forwards(input_row.text)
  end

  def output_handler
    if @editable
      convert_backwards(output_row.text)
    end
  end

  def change_input_base
    refresh_chrome
    @editable = true
  end

  # Upstream recomputes on an output-base change but not on an input-base one,
  # so that retyping is not needed after picking the base you meant to type in.
  def change_output_base
    input_handler
    refresh_chrome
    @editable = true
  end

  def on_close
    @settings['input_base'] = input_row.dropdown.selected
    @settings['output_base'] = output_row.dropdown.selected
    @settings.save
  end

  # --- conversion -------------------------------------------------------

  def convert_forwards(in_str)
    if in_str.empty?
      blank
      settle(bits: true)
    else
      show_forwards(in_str, Converter.answer(in_str, input_row.base, output_row.base))
    end
  end

  def show_forwards(in_str, answer)
    case answer
    when 'char'
      input_row.error = true
      input_row.tooltip = 'Invalid input'
      output_row.tooltip = nil
      settle(bits: false)
    when 'char_dual'
      flag_both(in_str, output_row)
      settle(bits: false)
    else
      output_row.text = answer
      clear_errors
      normalise_case(in_str)
    end
  end

  # Letters are entered in whichever case is convenient and displayed upper.
  # Rewriting the entry re-enters this handler, which is why the rest of the
  # update is left to that second pass.
  def normalise_case(in_str)
    if in_str == in_str.upcase
      settle(bits: true)
    else
      input_row.text = in_str.upcase
      input_row.entry.position = -1
    end
  end

  def convert_backwards(in_str)
    if in_str.empty?
      blank
      settle(bits: true)
    else
      show_backwards(in_str, Converter.answer(in_str, output_row.base, input_row.base))
    end
  end

  def show_backwards(in_str, answer)
    case answer
    when 'char'
      output_row.error = true
      output_row.tooltip = 'Invalid input'
      input_row.error = false
      input_row.tooltip = nil
      settle(bits: false)
    when 'char_dual'
      flag_both(in_str, input_row)
      settle(bits: false)
    else
      input_row.text = answer
      input_row.error = false
      output_row.error = false
      input_row.tooltip = nil
      settle(bits: true)
    end
    output_row.entry.position = -1
  end

  # Equal bases means an invalid string is invalid on both sides, so both
  # entries are flagged and the text is echoed across unconverted.
  def flag_both(in_str, echo_to)
    input_row.error = true
    output_row.error = true
    input_row.tooltip = 'Invalid input'
    output_row.tooltip = 'Invalid input'
    echo_to.text = in_str
  end

  def clear_errors
    [input_row, output_row].each do |row|
      row.error = false
      row.tooltip = nil
    end
  end

  def blank
    output_row.text = ''
    input_row.text = ''
    refresh_bits
    refresh_mono
    clear_errors
  end

  def settle(bits:)
    refresh_mono
    if bits
      refresh_bits
    end
    @editable = true
  end

  # --- display ----------------------------------------------------------

  def refresh_mono
    [input_row, output_row].each(&:refresh_mono)
  end

  def refresh_bits
    [input_row, output_row].each(&:refresh_bits)

    (input_row.digit_count + output_row.digit_count).positive?.then do |any|
      input_row.bit_button.sensitive = any
      output_row.bit_button.sensitive = any
    end
  end

  def refresh_chrome
    [input_row, output_row].each(&:refresh_visibility)
  end

  def restore_bases
    input_row.dropdown.selected = @settings['input_base']
    output_row.dropdown.selected = @settings['output_base']
    refresh_chrome
    blank
    @editable = true
  end

  # --- widgets ----------------------------------------------------------

  def window
    @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
      win.title = 'Binary'
      win.set_default_size(360, 390)
      win.set_size_request(360, 294)
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def window_handle = @window_handle ||= Gtk::WindowHandle.new

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |hb|
      hb.show_title = false
    end
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |btn|
      btn.primary = true
      btn.icon_name = 'open-menu-symbolic'
      btn.tooltip_text = 'Main Menu'
    end
  end

  def primary_menu
    @primary_menu ||= Gio::Menu.new.tap do |menu|
      menu.append_section(nil, window_section)
      menu.append_section(nil, app_section)
    end
  end

  def window_section
    @window_section ||= Gio::Menu.new.tap do |section|
      section.append('New Window', 'app.new-window')
    end
  end

  def app_section
    @app_section ||= Gio::Menu.new.tap do |section|
      section.append('_Keyboard Shortcuts', 'app.shortcuts')
      section.append('_About Binary', 'app.about')
    end
  end

  def clamp
    @clamp ||= Adwaita::Clamp.new.tap do |cl|
      cl.maximum_size = 600
      cl.tightening_threshold = 1000
    end
  end

  def content_box
    @content_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
      box.hexpand = true
      box.valign = :center
      box.margin_start = 30
      box.margin_end = 30
      box.margin_top = 30
      box.margin_bottom = 60
    end
  end

  def arrow_box
    @arrow_box ||= Gtk::Box.new(:horizontal, 9).tap do |box|
      box.margin_top = 18
      box.margin_bottom = 12
      box.valign = :center
      box.halign = :center
      box.hexpand = true
      box.add_css_class('typing-label')
    end
  end

  def arrow_image
    @arrow_image ||= Gtk::Image.new.tap do |image|
      image.icon_name = 'vertical-arrows-symbolic'
      image.icon_size = :normal
    end
  end

  def input_row
    @input_row ||= ConversionRow.new(
      tooltip:        'Input Base',
      on_base_change: method(:change_input_base),
      on_text_change: method(:input_handler),
    )
  end

  def output_row
    @output_row ||= ConversionRow.new(
      tooltip:        'Output Base',
      on_base_change: method(:change_output_base),
      on_text_change: method(:output_handler),
    )
  end
end
