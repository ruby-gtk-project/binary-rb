# frozen_string_literal: true

require 'adwaita'

require_relative 'converter'

# One half of the window: a base selector, a bit-count popover and the entry
# holding the number. The input and output halves are identical, so the window
# builds two of these.
class ConversionRow
  # Dropdown index -> number base. Index 4 is "Other", which reveals the spin
  # button and takes the base from there instead.
  BASES = [2, 8, 10, 16].freeze
  OTHER = 4

  def initialize(tooltip:, on_base_change:, on_text_change:)
    @tooltip = tooltip
    @on_base_change = on_base_change
    @on_text_change = on_text_change
  end

  def build
    container.tap do |box|
      box.append(center_box)
      box.append(entry)

      center_box.tap do |cb|
        cb.start_widget = controls_box
        cb.end_widget = bit_button

        controls_box.tap do |controls|
          controls.append(dropdown)
          controls.append(spin)

          dropdown.signal_connect('notify::selected') { @on_base_change.call }
          spin.signal_connect('changed') { @on_base_change.call }
        end

        bit_button.popover = bit_popover
      end

      bit_popover.tap do |popover|
        popover.child = bits_box

        bits_box.append(bits_label)
      end

      entry.signal_connect('changed') { @on_text_change.call }
    end
  end

  def text = entry.text

  def text=(value)
    entry.text = value
  end

  # The base this row is reading or writing in.
  def base
    if dropdown.selected < OTHER
      BASES[dropdown.selected]
    else
      spin.value.to_i
    end
  end

  def binary? = dropdown.selected.zero?

  def error=(flag)
    if flag
      entry.add_css_class('error')
    else
      entry.remove_css_class('error')
    end
  end

  def tooltip=(text)
    entry.tooltip_text = text
  end

  # Monospace only while there is something to line up.
  def refresh_mono
    if entry.text.empty?
      entry.remove_css_class('monospace')
    else
      entry.add_css_class('monospace')
    end
  end

  # Upstream counts decimal digits only, whatever the base — so "4B1" is 2.
  def digit_count = entry.text.gsub(/[^0-9]/, '').length

  def refresh_bits
    bit_button.label = self.class.bits_label(digit_count)
    bits_label.label = Converter.bit_count(entry.text)
  end

  def self.bits_label(count)
    if count == 1
      "#{count} bit"
    else
      "#{count} bits"
    end
  end

  # The bit counter is only meaningful for base 2, and the spin button only
  # applies to the "Other" entry in the dropdown.
  def refresh_visibility
    bit_button.visible = binary?
    spin.visible = dropdown.selected == OTHER
  end

  def container = @container ||= Gtk::Box.new(:vertical, 6)
  def center_box = @center_box ||= Gtk::CenterBox.new
  def controls_box = @controls_box ||= Gtk::Box.new(:horizontal, 0)
  def bit_popover = @bit_popover ||= Gtk::Popover.new
  def bits_box = @bits_box ||= Gtk::Box.new(:horizontal, 0)

  def dropdown
    @dropdown ||= Gtk::DropDown.new.tap do |dd|
      dd.model = Gtk::StringList.new(['Binary', 'Octal', 'Decimal', 'Hexadecimal', 'Other'])
      dd.tooltip_text = @tooltip
      dd.add_css_class('flat-dropdown')
    end
  end

  def spin
    @spin ||= Gtk::SpinButton.new(2, 36, 1).tap do |sb|
      sb.snap_to_ticks = true
      sb.set_increments(1, 2)
      sb.numeric = true
      sb.margin_start = 6
    end
  end

  def bit_button
    @bit_button ||= Gtk::MenuButton.new.tap do |btn|
      btn.hexpand = false
      btn.halign = :start
      btn.add_css_class('bitLbl')
      btn.add_css_class('flat')
    end
  end

  def entry
    @entry ||= Gtk::Entry.new.tap do |e|
      e.placeholder_text = 'Enter numbers'
      e.enable_undo = false
      # ponytail: upstream sets an explicit accessible label here. The Ruby
      # bindings raise NotImplementedError marshalling the array argument of
      # Gtk::Accessible#update_property, so the accessible name falls back to
      # the placeholder — the same words. Set the label properly once the
      # binding lands.
    end
  end

  def bits_label
    @bits_label ||= Gtk::Label.new('').tap do |label|
      label.wrap = true
      label.wrap_mode = :word
      label.max_width_chars = 30
    end
  end
end
