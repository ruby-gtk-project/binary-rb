# Component identification — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `ff54bec` |
| Round | 5 |
| Scan | `.claude/skills/component-identification/scripts/component-scan.sh` |
| Upstream rows | 47 (`.reports/upstream-components.tsv`) |
| Port rows | 49 (`.reports/port-components.tsv`, regenerated this round) |
| Upstream tree read via | `git archive origin/main` into a scratch directory — the ref is never checked out |

## The previous inventory was stale

`.reports/port-components.tsv` as committed before this round placed
`Adw.AboutDialog`, `Adw.PreferencesDialog`, `Adw.PreferencesPage`,
`Adw.ShortcutsDialog`, `Adw.ShortcutsItem` and `Adw.ShortcutsSection` in
`lib/main.rb`. Round 4 moved all six into `lib/about_dialog.rb`,
`lib/preferences_dialog.rb` and `lib/shortcuts_dialog.rb`; the TSV was not
regenerated, so the file that every parity comparison reads as its input
described a tree that no longer existed. Both TSVs are regenerated here.
This is carried into `.reports/accountability-ensurance.md` as a finding.

## Upstream units and their port counterparts

One upstream *component* is usually two upstream *files* — a Python class and
its Blueprint template — which the port merges into one Ruby file. The
mapping used for the comparison:

| Upstream files | Port file |
|---|---|
| `src/window.py` + `src/window.blp` | `lib/window.rb` + `lib/conversion_row.rb` |
| `src/lib/get_answer.py` + `src/lib/bit_count.py` | `lib/converter.rb` |
| `src/main.py` (application, actions, accels, CSS install) | `lib/main.rb` |
| `src/main.py:70-77` (`on_about_action`) | `lib/about_dialog.rb` |
| `src/preferences.py` + `src/preferences.blp` | `lib/preferences_dialog.rb` |
| `src/shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` |
| `src/style.css`, `src/style-hc.css` | `lib/main.rb` `STYLE`, `HIGH_CONTRAST_STYLE` heredocs |
| `data/*.gschema.xml` | `lib/settings.rb` (+ `data/schemas/`) |
| `src/binary.in` | `exe/binary` |
| `po/**`, `data/**` | shipped as-is |

17 components, matching the drive run's coverage count.

## Widget census, unioned per component

| Type | Upstream | Port | Note |
|---|---|---|---|
| `Adw.ApplicationWindow` | 1 | 1 | |
| `Adw.ToolbarView` | 1 | 1 | |
| `Adw.HeaderBar` | 1 | 1 | |
| `Adw.Clamp` | 1 | 1 | |
| `Gtk.WindowHandle` | 1 | 1 | |
| `Gtk.Box` | 6 | **8** | the port's `ConversionRow#container` is a vertical box per row that upstream's tree has no equivalent for (upstream puts the CenterBox and the Entry straight into the content box) |
| `Gtk.CenterBox` | 2 | 2 | |
| `Gtk.DropDown` | 2 | 2 | |
| `Gtk.SpinButton` | 2 | 2 | |
| `Gtk.Entry` | 2 | 2 | |
| `Gtk.MenuButton` | 3 | 3 | |
| `Gtk.Popover` | 2 | 2 | |
| `Gtk.Label` | 2 | 2 | |
| `Gtk.Image` | 1 | 1 | |
| `Adw.AboutDialog` | 1 | 1 | |
| `Adw.PreferencesWindow` | 1 | **0** | substituted by `Adw.PreferencesDialog` |
| `Adw.PreferencesPage` | 1 | 1 | |
| `Adw.ShortcutsDialog` | 1 | 1 | |
| `Adw.ShortcutsSection` | 1 | 1 | |
| `Adw.ShortcutsItem` | 4 | 4 | |
| `Adw.Application` | 1 | **0** | substituted by `Gtk.Application` (bindings) |
| `Gtk.Window` (default icon name) | 1 | 1 | |

## CSS classes

| Class | Upstream | Port |
|---|---|---|
| `bitLbl` | `src/window.blp` ×2 | `lib/conversion_row.rb` ×1, built twice |
| `flat` | ×2 | `lib/conversion_row.rb` ×1, built twice |
| `flat-dropdown` | ×2 | `lib/conversion_row.rb` ×1, built twice |
| `typing-label` | ×1 | `lib/window.rb` ×1 |
| `error` | `src/window.py` ×13 | `lib/conversion_row.rb#error=` |
| `monospace` | `src/window.py` ×4 | `lib/conversion_row.rb#refresh_mono` |

All six exist, and the three stylesheet rules that act on them
(`.bitLbl`, `.flat-dropdown button:not(:checked):not(:hover)`,
`.typing-label`) are byte-identical to `src/style.css`; `style-hc.css`'s one
rule is byte-identical too.

## Signals

| Signal | Upstream | Port |
|---|---|---|
| `close-request` | `window.blp` → `on_close` | `lib/window.rb` |
| `changed` (Entry ×2, SpinButton ×2) | `window.blp` ×4 | `lib/conversion_row.rb` ×2, built twice |
| `notify` (DropDown ×2) | `window.blp` ×2 | **`notify::selected`** ×1, built twice — narrowed |
| `activate` | `src/main.py` `do_activate` | `lib/main.rb` |
| `startup` | — (AdwApplication does it) | `lib/main.rb` (Adwaita.init, CSS, icons) |
| `handle-local-options` | `do_handle_local_options` | `lib/main.rb` |
| `command-line` | — (DEFAULT_FLAGS) | `lib/main.rb` — port-only, see component-parity |
| `notify::high-contrast` | — (AdwApplication resource loading) | `lib/main.rb` |

## Actions and accelerators

| Action | Upstream accel | Port accel |
|---|---|---|
| `app.quit` | `<primary>q` | `<primary>q` |
| `app.close-window` | `<primary>w` | `<primary>w` |
| `app.new-window` | `<primary>n` | `<primary>n` |
| `app.about` | none | none |
| `app.preferences` | none | none |
| `app.shortcuts` | **never created** (`src/window.blp` menu item and `src/shortcuts-dialog.blp` both point at a non-existent action) | created, `<primary>question` |

The component scanner does not extract GAction names from Ruby, so the port's
action rows are absent from `port-components.tsv`. They were read out of
`lib/main.rb` `ACTIONS` and `lib/window.rb`'s two menu sections, and the drive
run asserts each one against the live `Gio::Application` (checks 78–79).

## Menu items, pages, empty and error states

| Thing | Upstream | Port |
|---|---|---|
| Primary menu, section 1 | New Window | ✓ |
| Primary menu, section 2 | `_Keyboard Shortcuts`, `_About Binary` | ✓ |
| Desktop action | `new-window` in `.desktop.in` | file shipped ✓, never installed |
| Preferences page | one empty `Adw.PreferencesPage` | ✓ |
| Shortcuts section | `General`, 4 items | ✓ |
| Empty entries | both entries blank, bit buttons insensitive | ✓ |
| Error: invalid digit | `error` class + "Invalid input" tooltip on the offending entry | ✓ |
| Error: invalid digit, equal bases | both entries flagged, text echoed across | ✓ |
| Error: space / leading `-` | `char` | ✓ |
| Error: `.` across unequal bases | `char` | ✓ |
| Abort: `+` in input | handler raises, nothing changes | ✓ (`Converter::ABORT`) |
| Error: base-prefixed input (`0b11`, `0x1F`, `0o17`) | **no error — upstream converts** | **error invented by the port** |

The last row is the one new user-visible state this inventory turned up; it is
written up in `.reports/component-parity.md`.
