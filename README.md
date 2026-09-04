# binary-rb

A Ruby GTK4 / Libadwaita port of [Binary](https://github.com/fizzyizzy05/binary),
Isabelle Jackson's number-base converter. Type a number in one base, read it in
another; binary inputs also get a place-value breakdown in the bit-count
popover.

This is the `ruby` branch of the fork. Upstream's Python implementation lives
on `main`, and upstream does not accept AI-assisted contributions — nothing
here is intended to go back to it.

## Running

    nix develop        # or: direnv allow
    bundle install
    ruby bin/binary

`binary --new-window` opens an extra window in the instance already running.

## Tests

    rake          # the conversion and settings logic
    rake drive    # builds the real window, drives it, writes tmp/shots/*.png

The drive script runs headlessly — no display server, no Xvfb. Read the
screenshots it leaves behind; they catch what assertions do not.

## Layout

| File | What is in it |
|------|---------------|
| `lib/converter.rb` | base conversion and the bit-count string, no widgets |
| `lib/settings.rb` | the two remembered dropdown selections |
| `lib/conversion_row.rb` | one half of the window: base selector, bit popover, entry |
| `lib/window.rb` | the window, and the handlers that keep the two rows in step |
| `lib/main.rb` | application, actions, accelerators, About/Shortcuts/Preferences |

## Deliberate differences from upstream

- **Settings are a JSON file**, not GSettings. Upstream's schema has to be
  compiled and installed before the app will start; the file needs nothing.
  Stored at `$XDG_CONFIG_HOME/binary-rb/settings.json`.
- **No translations.** Upstream ships 30-odd `.po` files through gettext;
  the strings here are English literals.
- **The Keyboard Shortcuts action works.** Upstream's menu points at
  `app.shortcuts`, but `main.py` never creates that action, so the item is
  dead. The dialog from `shortcuts-dialog.blp` is built here, on
  <kbd>Ctrl</kbd>+<kbd>?</kbd>.
- **Typing `+` is invalid input** rather than an uncaught `TypeError`
  (`get_answer.py` calls a list).
- **No accessible label on the entries.** `Gtk::Accessible#update_property`
  raises `NotImplementedError` in the Ruby bindings; the accessible name falls
  back to the placeholder, which is the same wording.

Everything else is behaviour-for-behaviour, quirks included — see the comments
in `lib/converter.rb` for the ones that look like bugs and are.
