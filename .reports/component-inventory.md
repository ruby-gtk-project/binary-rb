# binary-rb — upstream component inventory

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` — Python 3 + PyGObject + Blueprint (GTK4 / libadwaita) |
| Port | `ruby` @ `89d9804` |
| App id | `io.github.fizzyizzy05.binary` |
| Method | `component-identification` skill: blueprint files read first, then `component-scan.sh` over both trees, then every source file read |

Binary is a single-window number-base converter. Two identical
base-selector + entry pairs sit stacked with an arrow between them; editing
either entry converts into the other. Each pair carries a bit-count popover
that is only shown while its base is binary. Around that: a primary menu, an
About dialog, an empty Preferences dialog, a shortcuts dialog, five app
actions and two stylesheets.

Upstream is small — five source files, three blueprints, two stylesheets, a
GSettings schema, a GResource manifest and 32 `po/` catalogues.

## Component list

Kinds: `app` application singleton · `window` · `dialog` · `menu` ·
`composite` repeated widget group · `logic` non-widget · `backend` ·
`style` · `data`.

| # | Upstream file(s) | → port file | Kind | Exists |
|--:|---|---|---|:-:|
| 1 | `src/main.py` | `lib/main.rb` | app | yes |
| 2 | `src/window.blp` + `src/window.py` | `lib/window.rb` | window | yes |
| 3 | `src/window.blp` (the two symmetric half-rows) | `lib/conversion_row.rb` | composite ×2 | yes |
| 4 | `src/window.blp` `menu primary_menu` | `lib/window.rb` (`#primary_menu`) | menu | yes |
| 5 | `src/window.blp` `Popover in_bit_popover` / `out_bit_popover` | `lib/conversion_row.rb` (`#bit_popover`) | composite ×2 | yes |
| 6 | `src/main.py` `on_about_action` + `data/…metainfo.xml.in` | `lib/about_dialog.rb` | dialog | yes |
| 7 | `src/preferences.blp` + `src/preferences.py` | `lib/preferences_dialog.rb` | dialog | yes |
| 8 | `src/shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | dialog | yes |
| 9 | `src/lib/get_answer.py` + `src/lib/bit_count.py` | `lib/converter.rb` | logic | yes — two files merged into one |
| 10 | `data/io.github.fizzyizzy05.binary.gschema.xml` | `lib/settings.rb` + `data/schemas/…gschema.xml` | backend | yes |
| 11 | `src/binary.in` (`bindtextdomain` / `gettext.install`) | `lib/i18n.rb` | backend | yes |
| 12 | `src/style.css` | `lib/main.rb` (`STYLE`) | style | yes |
| 13 | `src/style-hc.css` | `lib/main.rb` (`HIGH_CONTRAST_STYLE`) | style | yes |
| 14 | `src/binary.gresource.xml` | — (no bundle; `#install_styles` / `#install_icons` do the keying by hand) | data | n/a by design |
| 15 | `src/icons/scalable/actions/vertical-arrows-symbolic.svg` | `data/icons/hicolor/scalable/actions/` | data | yes |
| 16 | `data/…desktop.in` (incl. `[Desktop Action new-window]`) | `data/io.github.fizzyizzy05.binary.desktop.in` | data | yes — byte-identical |
| 17 | `data/…metainfo.xml.in` | `data/io.github.fizzyizzy05.binary.metainfo.xml.in` | data | yes |
| 18 | `data/…service.in` | `data/io.github.fizzyizzy05.binary.service.in` | data | yes |
| 19 | `po/` — `LINGUAS`, `POTFILES`, `binary.pot`, 32 `.po` | `po/` | data | yes — 32/32, `LINGUAS` identical |
| 20 | `meson.build`, `data/meson.build`, `src/meson.build`, `po/meson.build`, `subprojects/*.wrap` | `Rakefile` / `binary-rb.gemspec` | — | n/a by design |

No component in the list is missing from the port, and since round 4 every one
of them has a file of its own: items 6–8 were lifted out of `lib/main.rb` into
`lib/about_dialog.rb`, `lib/preferences_dialog.rb` and
`lib/shortcuts_dialog.rb`.

## Per-unit detail

### 1. `src/main.py` → `lib/main.rb` — the application singleton

| Widget | × | CSS | Signals / actions | Notes |
|---|--:|---|---|---|
| `Gtk.Application` | 1 | — | `activate`, `startup`, `handle-local-options`, `command-line` | upstream subclasses `Adw.Application`; the Ruby bindings' `Adwaita::Application` is broken, so the port uses `Gtk::Application` + `Adwaita.init` |
| `Gtk.Window` | 1 | — | — | `set_default_icon_name` only, not a built widget |

Actions and accelerators:

| Action | Accel upstream | Accel port | Notes |
|---|---|---|---|
| `app.quit` | `<primary>q` | `<primary>q` | |
| `app.about` | — | — | |
| `app.preferences` | — | — | |
| `app.close-window` | `<primary>w` | `<primary>w` | |
| `app.new-window` | `<primary>n` | `<primary>n` | |
| `app.shortcuts` | **never created** | created, `<primary>question` | upstream bug: `src/window.blp:187` and `src/shortcuts-dialog.blp:20` both target `app.shortcuts`, and `src/main.py` never calls `create_action` for it, so upstream's menu item and its own shortcuts dialog are dead. The port installs the action and opens the dialog |

CLI: `--new-window` / `-w` (`GLib.OptionArg.NONE`), handled in
`do_handle_local_options` by registering and forwarding the action to the
primary instance. The port reproduces this, and prepends `$0` to `ARGV`
because `g_application_run` skips argv[0].

Upstream never loads `shortcuts-dialog.ui` from Python at all — it is compiled
and bundled into the GResource and nothing reads it. Likewise `style.css` and
`style-hc.css` are bundled but never registered from Python; GTK picks them up
automatically from the resource path, which the port has no equivalent for, so
`#install_styles` registers the base sheet on the display permanently and
adds/removes the high-contrast one on `notify::high-contrast`.

### 2. `src/window.blp` + `src/window.py` → `lib/window.rb` — the main window

| Widget | × | CSS | Signals | Notes |
|---|--:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `close-request` → `on_close` | title "Binary", 360×390 default, 360×294 minimum; `on_close` writes `input-base` / `output-base` back to GSettings |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | `show-title: false` |
| `Gtk.MenuButton` | 1 | — | — | primary, `open-menu-symbolic`, tooltip "Main Menu", `menu-model: primary_menu` |
| `Gtk.WindowHandle` | 1 | — | — | |
| `Adw.Clamp` | 1 | — | — | `maximum-size: 600`, `tightening-threshold: 1000` |
| `Gtk.Box` (content) | 1 | — | — | vertical, spacing 6, margins 30/30/30/60, `valign: center` |
| `Gtk.Box` (arrow) | 1 | `typing-label` | — | margins 18/12, spacing 9, centred |
| `Gtk.Image` | 1 | — | — | `vertical-arrows-symbolic`, normal size |

Behaviour, all of it in `window.py` and all present in `window.rb`:
`input_handler`, `output_handler`, `change_input_base`, `change_output_base`,
`on_close`, `blank`, `update_bits`, `toggle_mono`, `toggle_bit_counter`,
`toggle_base_spin`, plus the `editable` re-entrancy flag that stops the two
entries writing into each other forever.

Dynamic CSS the scan cannot name, applied by the handlers:
`error` (on either `Gtk.Entry`, on `"char"` / `"char_dual"`),
`monospace` (on either entry while it has text).
Dynamic tooltips: `_("Invalid input")` or none, on either entry.

Conditional state: the bit-count `MenuButton`s are shown only while their own
base is binary; the `SpinButton`s only while their dropdown is on "Other"
(index 4); the bit labels are desensitised while both entries hold no digits.
Lowercase input is rewritten to uppercase with the cursor pushed to the end.

### 3. `src/window.blp` (two half-rows) → `lib/conversion_row.rb` — one base/entry pair, built twice

Upstream writes the two halves out twice in the blueprint; the port extracts
them into one class the window instantiates twice, so every count here is per
instance and doubles against upstream's.

| Widget | × | CSS | Signals | Notes |
|---|--:|---|---|---|
| `Gtk.CenterBox` | 1 | — | — | selector at start, bit button at end |
| `Gtk.Box` (controls) | 1 | — | — | dropdown + spin |
| `Gtk.DropDown` | 1 | `flat-dropdown` | `notify::selected` → base change | tooltip "Input Base" / "Output Base"; model is the five base names |
| `Gtk.SpinButton` | 1 | — | `changed` → base change | range 2–36, snap to ticks, increments 1/2, numeric, `margin-start: 6`, hidden unless base is "Other" |
| `Gtk.MenuButton` | 1 | `bitLbl`, `flat` | — | `halign: start`, no hexpand, opens the bit popover; label is the pluralised "%d bit(s)" |
| `Gtk.Popover` | 1 | — | — | `has-arrow: true` |
| `Gtk.Box` (popover) | 1 | — | — | |
| `Gtk.Label` (bits) | 1 | — | — | wrapping, `max-width-chars: 30`, word wrap; holds the `1 + 2 + 8 = 11` sum |
| `Gtk.Entry` | 1 | `error`, `monospace` (both dynamic) | `changed` → text change | placeholder "Enter numbers", `enable-undo: false`, accessible label "Enter numbers…" |

Base names, in dropdown order: `d_("Number base", "Binary")`, `_("Octal")`,
`_("Decimal")`, `_("Hexadecimal")`, `_("Other")` → bases 2, 8, 10, 16, spin.
"Binary" is looked up in a domain no catalogue defines, so it stays English —
upstream's behaviour, reproduced deliberately.

Repeater: none inside the row; the row itself is the ×2 repeat.

### 4. `src/window.blp` `menu primary_menu` → `lib/window.rb`

Two sections, three items, no `custom:` slots:

| Section | Item | Action |
|---|---|---|
| 1 | New Window | `app.new-window` |
| 2 | _Keyboard Shortcuts | `app.shortcuts` |
| 2 | _About Binary | `app.about` |

There is no Preferences item anywhere in the UI — `app.preferences` is
reachable only from the desktop shell. The port matches.

### 6. About dialog — `src/main.py:70-77` → `lib/about_dialog.rb`

Upstream builds it with `Adw.AboutDialog.new_from_appdata(…metainfo.xml, "5.4")`,
then overrides developers, designers, translator credits and copyright. The
port has no GResource, so it reads the same metainfo file off disk, pulls the
`<release version="5.4">` description out as AppStream markup for
`release-notes`, and sets the remaining fields explicitly. Rebuilt on every
activation, not memoized, because upstream makes a fresh dialog each time — as
are the preferences and shortcuts dialogs since round 4.

### 7. Preferences — `src/preferences.blp` + `src/preferences.py` → `lib/preferences_dialog.rb`

| Widget | × | Notes |
|---|--:|---|
| `Adw.PreferencesWindow` | 1 | title "Preferences", 400×306 default, 200 minimum height |
| `Adw.PreferencesPage` | 1 | **empty** — no groups, no rows |

An empty shell upstream, and an empty shell in the port. The port substitutes
`Adwaita::PreferencesDialog` (the window class is deprecated) and uses
`content-width` / `content-height`, which is what `AdwDialog` calls a default
size. `group-digits` exists in the GSettings schema and no widget binds it.

### 8. Shortcuts — `src/shortcuts-dialog.blp` → `lib/shortcuts_dialog.rb`

A standalone blueprint object with no backing source file, and nothing
upstream ever loads it.

| Widget | × | Notes |
|---|--:|---|
| `Adw.ShortcutsDialog` | 1 | |
| `Adw.ShortcutsSection` | 1 | title `C_("shortcut window", "General")` |
| `Adw.ShortcutsItem` | 4 | New Window / Close Window / Show Shortcuts / Quit, each `action-name` on an `app.*` action |

The port writes the four `c_` calls out one by one rather than looping a
table, so `xgettext` can see all five msgids.

### 9. `src/lib/get_answer.py` + `src/lib/bit_count.py` → `lib/converter.rb`

Pure logic, no widgets. `get_answer` returns either the converted string or
one of two sentinels — `"char"` (invalid in its own base) and `"char_dual"`
(invalid and both bases equal, so both entries get flagged). `bit_count`
builds the `1 + 2 + 8 = 11` popover string.

Two upstream behaviours the port reproduces rather than fixes:
`"+"` in the input calls a list (`split_input('')`) and raises, leaving the
handler half-finished with no answer and no error styling — the port names
that outcome `ABORT`; and negative input is rejected outright as `"char"`.

### 10–13, 15–19. Non-widget parity

- GSettings: schema byte-identical, keys `group-digits` (unused), `input-base`
  (default 0), `output-base` (default 2). `lib/settings.rb` wraps it.
- gettext: upstream binds the `binary` domain in `src/binary.in`;
  `lib/i18n.rb` binds the same domain through libc/libintl with Fiddle and
  defines `_`, `d_`, `c_`, `n_`.
- Stylesheets: `.bitLbl`, `.flat-dropdown button:not(:checked):not(:hover)`
  and `.typing-label` from `style.css`; the one `.typing-label` opacity
  override from `style-hc.css`. All three classes are applied; none is dead.
- `po/`: 32 catalogues on both sides, `LINGUAS` identical. `POTFILES` points
  at the port's own `lib/*.rb` and `data/` instead of upstream's `src/`.
- Desktop entry, metainfo and D-Bus service file all shipped, desktop entry
  byte-identical including the `new-window` desktop action.

## What is not a component

`meson.build` (×4) and `subprojects/blueprint-compiler.wrap` are the build
system, replaced by the Rakefile and gemspec. `src/__init__.py` is empty.
`src/binary.gresource.xml` has no port equivalent by design — the house style
builds widgets in Ruby, so there is no `.ui` to bundle, and the two things the
bundle did carry that still matter (the stylesheets, the arrow icon) are
handled by `#install_styles` and `#install_icons`. `img/*.png`,
`binary.doap`, `io.github.fizzyizzy05.binary.json` and
`update_translations.sh` are repository furniture.

## Gaps

1. ~~**Three dialogs have no file of their own.**~~ Closed in round 4: About,
   Preferences and Shortcuts moved out of `lib/main.rb` into
   `lib/about_dialog.rb`, `lib/preferences_dialog.rb` and
   `lib/shortcuts_dialog.rb`. `lib/main.rb` keeps the application, the actions
   and the two stylesheets.
2. **`src/lib/get_answer.py` and `src/lib/bit_count.py` share
   `lib/converter.rb`.** Defensible — they are 40 lines between them and one
   module is the natural shape — but it is the same rule bent a second time.
3. **No specs.** `spec/` holds `spec_helper.rb` and a README and nothing else,
   against upstream's own empty test suite. Not a component gap; recorded
   because the converter's sentinel behaviour is the most testable thing in
   the app, and what covers it is `test/test_converter.rb` under minitest
   rather than anything under `spec/`.
