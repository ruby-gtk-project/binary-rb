# binary-rb — upstream component inventory

Upstream: **Python 3 + PyGObject + Blueprint** (GTK4 / libadwaita), app id
`io.github.fizzyizzy05.binary`, read from `origin/main`.
Binary is a one-window number-base converter: two stacked base-selector +
entry pairs that convert into each other live, with a per-entry bit-count
popover for binary.

Upstream is five source files (`src/main.py`, `src/window.py` + `src/window.blp`,
`src/preferences.py` + `src/preferences.blp`, `src/shortcuts-dialog.blp`,
`src/lib/{bit_count,get_answer}.py`) plus two stylesheets, a GSettings schema,
a GResource manifest and 32 `po/` catalogues.

The `ruby` branch is **not** a skeleton. Nine `lib/*.rb` files are present and
seven of them are a working full port; two are the original scaffold and are now
dead code.

## Unit map

| # | Upstream files | → port file | Kind | State |
|--:|---|---|---|---|
| 1 | `src/main.py` | `lib/main.rb` | application singleton, actions, accels, CLI | present |
| 2 | `src/window.blp` + `src/window.py` | `lib/window.rb` | main window | present |
| 3 | `src/window.blp` (the two half-rows) | `lib/conversion_row.rb` | repeated composite (×2) | present |
| 4 | `src/window.blp` `menu primary_menu` | `lib/window.rb` | menu model | present |
| 5 | `src/shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | dialog | **implemented inline in `lib/main.rb`** |
| 6 | `src/preferences.blp` + `src/preferences.py` | `lib/preferences_dialog.rb` | dialog | **implemented inline in `lib/main.rb`** |
| 7 | `src/main.py` `on_about_action` + `data/*.metainfo.xml.in` | `lib/about_dialog.rb` | dialog | **implemented inline in `lib/main.rb`** |
| 8 | `src/lib/get_answer.py`, `src/lib/bit_count.py` | `lib/converter.rb` | pure logic | present |
| 9 | `data/*.gschema.xml` | `lib/settings.rb` | settings backend | present |
| 10 | `src/binary.in` (`locale.bindtextdomain`/`gettext.install`) | `lib/i18n.rb` | gettext backend | present |
| 11 | `src/style.css` | `lib/main.rb` (`STYLE`) | stylesheet | present |
| 12 | `src/style-hc.css` | `lib/main.rb` | high-contrast stylesheet | **MISSING** |
| 13 | `src/icons/.../vertical-arrows-symbolic.svg` | `data/icons/hicolor/scalable/actions/` | icon | present |
| — | `lib/binary.rb`, `lib/binary/application.rb` | — | scaffold | **dead, delete** |

Units 5–7 are ported behaviour sitting in the wrong file. The house rule is one
upstream source file to one `lib/*.rb`; `lib/main.rb` currently owns three
dialogs that upstream declares separately. Splitting them is a refactor, not a
port.

## src/main.py → lib/main.rb — the application singleton

| Item | × | Detail | Port |
|---|---:|---|---|
| `Adw.Application` | 1 | `application_id`, `DEFAULT_FLAGS` | `Gtk::Application` + `:handles_command_line` (Adwaita::Application is broken in the bindings; the flag is how `--new-window` reaches a running instance) |
| action `app.quit` | 1 | accel `<primary>q` | yes |
| action `app.about` | 1 | no accel | yes |
| action `app.preferences` | 1 | no accel, no menu item anywhere | yes |
| action `app.close-window` | 1 | accel `<primary>w` | yes |
| action `app.new-window` | 1 | accel `<primary>n` | yes |
| action `app.shortcuts` | 0 | **referenced by the menu and the shortcuts dialog but never created upstream** — the menu item is dead on upstream | port creates it, with accel `<primary>question` |
| `Adw.AboutDialog.new_from_appdata` | 1 | metainfo + developers, designers, translator-credits, copyright | hand-built `Adwaita::AboutDialog` (no GResource to read appdata from) |
| `Gtk.Window.set_default_icon_name` | 1 | — | yes |
| main option `--new-window` / `-w` | 1 | `do_handle_local_options` re-dispatches to the running instance | yes, via `command-line` |
| CSS auto-load | 2 | `Adw.Application` auto-loads `style.css` **and `style-hc.css`** from the resource base path | only `style.css` ported |

## src/window.blp + src/window.py → lib/window.rb

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `close-request` → `on_close` | title "Binary", 360×390 default, 360×294 minimum; saves both base indices on close |
| `Adw.ToolbarView` | 1 | — | — | — |
| `Adw.HeaderBar` | 1 | — | — | `show-title: false` |
| `Gtk.MenuButton` | 1 | — | — | primary, `open-menu-symbolic`, tooltip `Main Menu`, `primary_menu` |
| `Gtk.WindowHandle` | 1 | — | — | whole body draggable |
| `Adw.Clamp` | 1 | — | — | max 600, tightening 1000 |
| `Gtk.Box` (content) | 1 | — | — | vertical, spacing 6, margins 30/30/30/60, `valign: center` |
| `Gtk.Box` (arrow) | 1 | `typing-label` | — | spacing 9, margins 18/12, centred |
| `Gtk.Image` | 1 | — | — | `vertical-arrows-symbolic`, icon-size normal |

All present on the port.

**Behaviour** (`src/window.py`, all ported to `lib/window.rb`): the `editable`
re-entrancy guard; `input_handler` / `output_handler` converting each way;
`char` flags the source entry only, `char_dual` flags both and echoes the text
across; lowercase input is rewritten upper-case with the cursor sent to the end;
`toggle_mono` adds/removes `monospace`; `update_bits` relabels both bit buttons
with an ngettext plural and desensitises them when both entries hold no decimal
digits; `toggle_bit_counter` shows a bit button only when its own base is
binary; `toggle_base_spin` reveals a spin button only for the "Other" base;
`change_input_base` deliberately does **not** reconvert while
`change_output_base` does.

### menu primary_menu → lib/window.rb

| Section | Items |
|---|---|
| 1 | `New Window` → `app.new-window` |
| 2 | `_Keyboard Shortcuts` → `app.shortcuts`, `_About Binary` → `app.about` |

Present as two `Gio::Menu` sections. No `app.preferences` item — matching upstream.

## src/window.blp (half-row) → lib/conversion_row.rb — built twice

| Widget | × per row | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.CenterBox` | 1 | — | — | controls at start, bit button at end |
| `Gtk.Box` (controls) | 1 | — | — | dropdown + spin |
| `Gtk.DropDown` | 1 | `flat-dropdown` | `notify` → base change | model `Binary, Octal, Decimal, Hexadecimal, Other`; "Binary" asked for out of the non-existent `Number base` domain, so it stays English — reproduced faithfully |
| `Gtk.SpinButton` | 1 | — | `changed` → base change | range 2–36, snap to ticks, increments 1/2, numeric, `margin-start: 6`; visible only for "Other" |
| `Gtk.MenuButton` (bit label) | 1 | `bitLbl`, `flat` | — | label is the plural bit count; opens the popover |
| `Gtk.Popover` | 1 | — | — | `has-arrow` |
| `Gtk.Box` (popover) | 1 | — | — | — |
| `Gtk.Label` (bits) | 1 | — | — | wrap, word mode, max 30 chars; the `8 + 2 = 1010` sum |
| `Gtk.Entry` | 1 | `error` (dyn), `monospace` (dyn) | `changed` → text handler | placeholder `Enter numbers`, `enable-undo: false`, accessible label `Enter numbers…`, tooltip `Invalid input` when flagged |

Repeater: the whole row, ×2 (input and output). The port adds one wrapping
`Gtk::Box` per row that upstream does not have — an artefact of making the row a
class, not a parity gap.

Dynamic CSS: `error` and `monospace` on both entries; no other dynamic classes.

## src/shortcuts-dialog.blp → should be lib/shortcuts_dialog.rb

`Adw.ShortcutsDialog` with one `Adw.ShortcutsSection` titled
`C_("shortcut window", "General")` and four `Adw.ShortcutsItem`s: New Window,
Close Window, Show Shortcuts, Quit — all translated out of the
`shortcut window` context. Upstream compiles the file into the GResource but
never loads it and never creates `app.shortcuts`, so upstream's menu item does
nothing. The port builds the dialog and wires the action.

## src/preferences.blp + src/preferences.py → should be lib/preferences_dialog.rb

`Adw.PreferencesWindow` titled `Preferences`, 400×306 default, 200 minimum
height, containing one empty `Adw.PreferencesPage`. No rows, no groups: it is a
placeholder reached only through `app.preferences`, which no menu exposes. The
port builds an `Adwaita::PreferencesDialog` with one empty page.

## src/lib/get_answer.py, src/lib/bit_count.py → lib/converter.rb

No widgets. `get_answer` returns the converted string or the sentinels `char` /
`char_dual`; spaces and a leading `-` are invalid, equal bases echo the input,
fractional parts are rejected except `.0`, digits above 9 become `A`–`Z` up to
base 36. `bit_count` renders `8 + 2 = 1010`, with upstream's quirk that the sum
is read as binary place values while the right-hand side is the input read as
decimal, and the `= n` tail is dropped for non-decimal input. Both quirks are
reproduced and commented in the port.

## data/io.github.fizzyizzy05.binary.gschema.xml → lib/settings.rb

Three `i` keys: `input-base` (0), `output-base` (2), `group-digits` (0).
`group-digits` is read by nothing on either side. The port keeps upstream's
schema id and key names so both apps share stored state.

## Translations

32 `po/*.po` + `po/binary.pot` + `LINGUAS` are already on the `ruby` branch and
match upstream file-for-file. `po/POTFILES` has been retargeted at the Ruby
sources. `lib/i18n.rb` binds libc gettext through Fiddle, including `dgettext`,
the `\u0004` context separator and `dngettext`, and rewrites Python's
`%(name)d` placeholders so the existing catalogues keep working untouched.

## Gaps to close

1. **`src/style-hc.css` is not ported** — `.typing-label { opacity: 0.75 }`
   under high contrast. Upstream gets it free from `Adw.Application`'s resource
   auto-loading; because the port uses `Gtk::Application` it must install a
   second `Gtk::CssProvider` and follow
   `Adwaita::StyleManager#high_contrast`.
2. **Dead scaffold** — `lib/binary.rb` and `lib/binary/application.rb` still
   hold the blank status-page app under a different app id
   (`org.rubygtkproject.Binary`). Delete both; the real entry point is
   `exe/binary` → `lib/main.rb`.
3. **Three dialogs live in `lib/main.rb`** — split out `lib/shortcuts_dialog.rb`,
   `lib/preferences_dialog.rb` and `lib/about_dialog.rb` to restore the
   one-upstream-file-to-one-`lib`-file rule.
4. **No D-Bus service file** — upstream ships
   `data/io.github.fizzyizzy05.binary.service.in`; the `ruby` branch has none,
   so D-Bus activation is unavailable.

## Not portable

- `src/binary.gresource.xml`, `src/meson.build`, `data/meson.build`,
  `po/meson.build`, `subprojects/blueprint-compiler.wrap` — the Meson +
  GResource + blueprint-compiler build chain. The port is a gem: widgets are
  built in Ruby, CSS is a heredoc, and the icon is found via an
  `Gtk::IconTheme` search path.
- `Adw.AboutDialog.new_from_appdata` — needs the metainfo inside a compiled
  GResource, so the about dialog is populated by hand instead.
- `Gtk::Accessible#update_property` raises `NotImplementedError` in the
  bindings, so the entries' accessible labels are applied through a tiny
  `Gtk::Builder` XML document in `lib/conversion_row.rb`.
