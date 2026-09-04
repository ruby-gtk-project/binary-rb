# frozen_string_literal: true

require 'adwaita'

require_relative 'converter'
require_relative 'i18n'

# One half of the window: a base selector, a bit-count popover and the entry
# holding the number. The input and output halves are identical, so the window
# builds two of these.
class ConversionRow
  # Dropdown index -> number base. Index 4 is "Other", which reveals the spin
  # button and takes the base from there instead.
  BASES = [2, 8, 10, 16].freeze
  OTHER = 4

  # Built on demand rather than frozen into a constant, because the text domain
  # is not bound until the application starts. "Binary" is asked for out of a
  # domain no catalogue defines, exactly as upstream does, so it stays English.
  BASE_NAMES = lambda do
    [
      d_('Number base', 'Binary'),
      _('Octal'),
      _('Decimal'),
      _('Hexadecimal'),
      _('Other'),
    ]
  end

  def initialize(tooltip:, bit_plural:, on_base_change:, on_text_change:)
    @tooltip = tooltip
    @bit_plural = bit_plural
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
    bit_button.label = n_(*@bit_plural, digit_count)
    bits_label.label = Converter.bit_count(entry.text)
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
      dd.model = Gtk::StringList.new(BASE_NAMES.call)
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

  # Built from XML rather than by hand: the accessible label is the one piece
  # of upstream's entry the bindings cannot set directly, because
  # Gtk::Accessible#update_property raises NotImplementedError marshalling its
  # array argument. GtkBuilder applies it for us.
  def entry
    @entry ||= Gtk::Builder.new(string: self.class.entry_ui).get_object('entry')
  end

  def self.entry_ui
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <interface>
        <object class="GtkEntry" id="entry">
          <property name="placeholder-text">#{escape(_('Enter numbers'))}</property>
          <property name="enable-undo">false</property>
          <accessibility>
            <property name="label">#{escape(_('Enter numbers…'))}</property>
          </accessibility>
        </object>
      </interface>
    XML
  end

  # Translations arrive from the catalogues, so they go through XML escaping
  # before being interpolated into the builder document.
  def self.escape(text)
    text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end

  def bits_label
    @bits_label ||= Gtk::Label.new('').tap do |label|
      label.wrap = true
      label.wrap_mode = :word
      label.max_width_chars = 30
    end
  end
end
