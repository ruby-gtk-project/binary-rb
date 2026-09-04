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
    ruby bin/binary

The gems are built by nix from `gemset.nix`, so there is no `bundle install`
step. After changing the `Gemfile`, regenerate the lock and the gem set with
`bundix -l` and commit both.

`binary --new-window` opens an extra window in the instance already running.

## Tests

    rake          # conversion, settings and translation logic, then rubocop
    rake drive    # builds the real window, drives it, writes tmp/shots/*.png

`rake drive` runs two scripts: the window under the default locale, and the
same window under `LANGUAGE=de` to prove the catalogues reach the widgets. Both
run headlessly — no display server, no Xvfb. Read the screenshots they leave
behind; they catch what assertions do not.

`rake` also compiles the GSettings schema and the message catalogues, which the
app needs before it will start from a checkout.

## Layout

| File | What is in it |
|------|---------------|
| `lib/converter.rb` | base conversion and the bit-count string, no widgets |
| `lib/i18n.rb` | gettext, bound through Fiddle to the one GTK already uses |
| `lib/settings.rb` | GSettings, under upstream's schema id and keys |
| `lib/conversion_row.rb` | one half of the window: base selector, bit popover, entry |
| `lib/window.rb` | the window, and the handlers that keep the two rows in step |
| `lib/main.rb` | application, actions, About/Shortcuts/Preferences |
| `po/` | upstream's catalogues, compiled into `locale/` by `rake translations` |
| `data/schemas/` | upstream's GSettings schema, compiled by `rake schemas` |

## Notes on the port

- **Translations go through libc gettext, via Fiddle.** There is no gettext in
  the Ruby standard library and none in the ruby-gnome bindings. Binding to the
  C implementation GTK is already using means one catalogue reader rather than
  two, and plural rules, the `LANGUAGE` search list and encoding conversion all
  come for free. `lib/i18n.rb` is the whole of it.
- **The entries are built from GtkBuilder XML**, because
  `Gtk::Accessible#update_property` raises `NotImplementedError` in the
  bindings and that is the only way to set their accessible label.
- **`Adwaita::ShortcutsItem.new(title, action)` sets an accelerator, not an
  action** — both two-argument constructors take `(String, String)` and the
  bindings always pick the first. The action name goes on afterwards.
- **The Keyboard Shortcuts action works.** Upstream's menu points at
  `app.shortcuts`, but `main.py` never creates that action, so the item is
  dead. The dialog from `shortcuts-dialog.blp` is built here, on
  <kbd>Ctrl</kbd>+<kbd>?</kbd>.
- **Typing `+` is invalid input** rather than an uncaught `TypeError`
  (`get_answer.py` calls a list).
- **The base names are asked for out of a domain called `Number base`**, which
  no catalogue defines, so they stay English — exactly as upstream. Translating
  them would be a difference, not a fix.

Everything else is behaviour-for-behaviour, quirks included — see the comments
in `lib/converter.rb` for the ones that look like bugs and are.
