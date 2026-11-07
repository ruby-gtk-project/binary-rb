# frozen_string_literal: true

require 'adwaita'

require_relative 'i18n'

# The keyboard shortcuts dialog.
#
# A direct port of src/shortcuts-dialog.blp: an Adw.ShortcutsDialog with one
# Adw.ShortcutsSection titled C_("shortcut window", "General") and four
# Adw.ShortcutsItems, each naming an app action rather than an accelerator, so
# the accelerators shown are whatever the application has bound to them.
#
# Upstream never loads this blueprint from Python — it is compiled into the
# GResource bundle and nothing reads it, and src/main.py never creates the
# app.shortcuts action its own menu item and items point at. The port installs
# that action and opens this dialog from it — a decided, permanent
# divergence (PORTING.md item 6, .reports/component-parity.md's
# "dead-reference fix" rule), not an oversight.
class ShortcutsDialog
  def build
    dialog.tap do |shortcuts|
      shortcuts.add(general_section)

      general_section.tap do |section|
        # One c_ call per item, with the context and the msgid written out,
        # because a table of titles walked in a loop is five msgids xgettext
        # cannot see — and a msgid that does not reach po/binary.pot is marked
        # obsolete in all 32 catalogues on the next `rake pot`. Upstream writes
        # them out the same way, in src/shortcuts-dialog.blp:6, :9, :14, :19,
        # :24.
        section.add(item(c_('shortcut window', 'New Window'), 'app.new-window'))
        section.add(item(c_('shortcut window', 'Close Window'), 'app.close-window'))
        section.add(item(c_('shortcut window', 'Show Shortcuts'), 'app.shortcuts'))
        section.add(item(c_('shortcut window', 'Quit'), 'app.quit'))
      end
    end
  end

  def dialog = @dialog ||= Adwaita::ShortcutsDialog.new

  def general_section
    @general_section ||= Adwaita::ShortcutsSection.new.tap do |section|
      section.title = c_('shortcut window', 'General')
    end
  end

  # Both two-argument constructors take (title, String), and the bindings
  # always resolve that to the accelerator one — hence the empty accelerator
  # and the setter for the action name.
  def item(title, action)
    Adwaita::ShortcutsItem.new(title, '').tap do |shortcut|
      shortcut.action_name = action
    end
  end
end
