# Component identification — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` (Python 3 + PyGObject + Blueprint) |
| Port | `ruby` @ `eff4fa3` |
| Scan | `.claude/skills/component-identification/scripts/component-scan.sh`, with `scripts/symbols.tsv` present |
| Upstream rows | 47 |
| Port rows | 47 |
| Round | 3 — rescanned against `eff4fa3`, not against the tree round 2 described |

Upstream has declarative UI, so Step 1 applies: `src/*.blp` **is** the inventory
and the unit list. Three declarative roots:

| Root | Kind | Unit |
|---|---|---|
| `template $BinaryWindow: Adw.ApplicationWindow` (`src/window.blp`) | template | the window |
| `template $PrefsWindow: Adw.PreferencesWindow` (`src/preferences.blp`) | template | preferences |
| `Adw.ShortcutsDialog shortcuts_dialog` (`src/shortcuts-dialog.blp`) | **named root, no template** | shortcuts |

Plus two units with no widget class of their own:

- the application class `BinaryApplication(Adw.Application)` (`src/main.py`) — actions, accels, About, the preferences entry point, `--new-window`;
- the conversion library `src/lib/get_answer.py` + `src/lib/bit_count.py` — no widgets, pure behaviour.

## File mapping

```
src/window.py + src/window.blp             -> lib/window.rb + lib/conversion_row.rb
src/preferences.py + src/preferences.blp   -> lib/main.rb  (#preferences_dialog)
src/shortcuts-dialog.blp                   -> lib/main.rb  (#shortcuts_dialog, #general_shortcuts, #shortcut_item)
src/main.py                                -> lib/main.rb + exe/binary + lib/binary.rb
src/lib/get_answer.py + src/lib/bit_count.py -> lib/converter.rb
src/style.css                              -> lib/main.rb  STYLE (heredoc)
src/style-hc.css                           -> lib/main.rb  HIGH_CONTRAST_STYLE (heredoc)
data/io.github.fizzyizzy05.binary.gschema.xml -> data/schemas/… + lib/settings.rb
```

Three upstream units (preferences, shortcuts, the About dialog) have **no
`lib/*.rb` of their own** — see the gap in `.reports/component-parity.md`.

## src/window.blp + src/window.py — the one window, two conversion halves

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `close-request` → `on_close` | title `Binary` (unmarked upstream and in the port), default 360×390, request 360×294 |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | `show-title: false` |
| `Gtk.MenuButton` | 3 | `bitLbl`+`flat` (2 of 3) | — | 1 primary menu button (`open-menu-symbolic`, tooltip `Main Menu`), 2 bit-count buttons each hosting a `Gtk.Popover` |
| `Gtk.WindowHandle` | 1 | — | — | |
| `Adw.Clamp` | 1 | — | — | max 600, tightening 1000 |
| `Gtk.Box` | 6 | `typing-label` (1 of 6) | — | content box (spacing 6, margins 30/30/30/60), 2 dropdown+spin boxes, the arrow box, 2 popover boxes |
| `Gtk.CenterBox` | 2 | — | — | start = dropdown+spin, end = bit button |
| `Gtk.DropDown` | 2 | `flat-dropdown` | `notify` (**every** property, not just `selected`) | tooltips `Input Base` / `Output Base`; model is a 5-item `Gtk.StringList` |
| `Gtk.SpinButton` | 2 | — | `changed` | range 2–36, snap to ticks, increments (1,2), numeric, margin-start 6; visible only for base "Other" |
| `Gtk.Entry` | 2 | `error`, `monospace` (both dynamic) | `changed` → `input_handler` / `output_handler` | placeholder `Enter numbers`, accessible label `Enter numbers…`, `enable-undo: false` |
| `Gtk.Image` | 1 | — | — | `vertical-arrows-symbolic`, icon-size normal |
| `Gtk.Popover` | 2 | — | — | `has-arrow: true` |
| `Gtk.Label` | 2 | — | — | the bit sums; wrap, word mode, max 30 chars |
| `Gio.Menu` (`menu primary_menu`) | 1 | — | — | 2 sections, 3 items: `New Window` → `app.new-window`; `_Keyboard Shortcuts` → `app.shortcuts`; `_About Binary` → `app.about` |

Dynamic CSS, resolved by reading `src/window.py`: `error` added/removed on both
entries by `input_handler`/`output_handler`/`blank` (13 attachment sites);
`monospace` added/removed by `toggle_mono` (4 sites). Repeaters: none —
the two halves are written out twice in the `.blp`. Conditional: the spin
buttons (`toggle_base_spin`, base "Other" only) and the bit buttons
(`toggle_bit_counter`, binary only).

Port side: `lib/window.rb` builds the window, header bar, menu, clamp, content
box and arrow box; `lib/conversion_row.rb` is one half, instantiated twice, so
all of its counts double. The port adds **two** `Gtk::Box` upstream does not
have — `ConversionRow#container`, the per-half vertical box — taking the content
box from 5 children to 3. The `css`, `signal` and widget sets otherwise match
one for one, and `notify` is narrowed to `notify::selected`.

## src/preferences.blp + src/preferences.py — the preferences window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesWindow` | 1 | — | — | title `Preferences`, default 400×306, height-request 200 |
| `Adw.PreferencesPage` | 1 | — | — | **empty** — upstream has no rows in it |

`PrefsWindow.__init__` constructs a `Gio.Settings` it never reads. Nothing in
upstream's menu opens this window; only the `app.preferences` action does, and
the only caller of that is the desktop shell.

## src/shortcuts-dialog.blp — the shortcuts dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ShortcutsDialog` | 1 | — | — | named root, no template |
| `Adw.ShortcutsSection` | 1 | — | — | title `C_("shortcut window", "General")` |
| `Adw.ShortcutsItem` | 4 | — | — | `New Window` → `app.new-window`, `Close Window` → `app.close-window`, `Show Shortcuts` → `app.shortcuts`, `Quit` → `app.quit` |

Compiled into `src/binary.gresource.xml` and **never loaded by any upstream
source file.** `src/main.py` creates no `shortcuts` action, so upstream's
`_Keyboard Shortcuts` menu item and this dialog's `Show Shortcuts` row both
point at an action that does not exist. Recorded as an upstream bug in
`FINDINGS.md`.

## src/main.py — the application

| Component | × | Notes |
|---|---:|---|
| `Adw.Application` | 1 | app id `io.github.fizzyizzy05.binary`, `Gio.ApplicationFlags.DEFAULT_FLAGS` |
| `Adw.AboutDialog` | 1 | `new_from_appdata("io/github/fizzyizzy05/binary/metainfo.xml", "5.4")`, built fresh on every activation; developers, designers, `_("translator-credits")`, copyright set by hand |
| `Gtk.Window.set_default_icon_name` | 1 | `io.github.fizzyizzy05.binary` |
| actions | 5 | `quit` (`<primary>q`), `about` (no accel), `preferences` (no accel), `close-window` (`<primary>w`), `new-window` (`<primary>n`) |
| main option | 1 | `--new-window` / `-w`, `GLib.OptionArg.NONE`, description `Open a new window` (**unmarked** upstream) |
| signals | 1 | `do_activate`; `do_handle_local_options` is a vfunc override |

Actions referenced but **not installed**: `app.shortcuts` (2 reference sites).

Port side: `lib/main.rb` installs **six** actions — upstream's five plus
`shortcuts`, with an accelerator `<primary>question` that upstream never set —
and uses `Gtk::Application` with `:handles_command_line` rather than
`Adw.Application` with `DEFAULT_FLAGS`.

## src/lib/get_answer.py + src/lib/bit_count.py — the conversion library

No widgets. `get_answer` returns the converted string or the sentinels `char` /
`char_dual`; spaces and a leading `-` are invalid; equal bases echo the input
untouched; any `.` is refused across unequal bases; digits above 9 become `A`–`Z`
up to base 36. `bit_count` renders `8 + 2 = 1010`, reading the `1` digits as
binary place values while the `= n` tail reads the input as **decimal**, and
dropping that tail (trailing `" + "` and all) for non-decimal input. A third
outcome exists and is not a return value: `if '+' in input: split_input('')`
calls a list and raises `TypeError`, killing the calling handler mid-way.
All three behaviours are reproduced in `lib/converter.rb`.

## src/style.css + src/style-hc.css — the stylesheets

Three app-namespaced classes, all attached in `src/window.blp`: `.bitLbl`
(`font-size: 0.9em`), `.flat-dropdown button:not(:checked):not(:hover)`
(transparent background, no box-shadow), `.typing-label` (`font-size: 0.9em`,
`opacity: 0.5`, `font-weight: 700`). The high-contrast sheet overrides
`.typing-label { opacity: 0.75 }` and nothing else. Both are loaded by
`AdwApplication` from the GResource base path, not by any explicit
`CssProvider` call. Platform classes also in play and defined by GTK, not by
either sheet: `flat`, `error`, `monospace`.

## data/io.github.fizzyizzy05.binary.gschema.xml — stored state

Three `i` keys: `input-base` (default 0), `output-base` (default 2),
`group-digits` (default 0). `group-digits` is read by nothing on either side.

## What the scan could not see, and had to be read

- **The port installs no `action` rows at all.** `lib/main.rb` builds its six actions from the `ACTIONS` hash with `"app.#{name}"` interpolated, and `lib/window.rb` passes `'app.new-window'`/`'app.shortcuts'`/`'app.about'` to `Gio::Menu#append`; none of those shapes is matched. Every action on the port side in this document was read off the source.
- **`Adw.ShortcutsItem` ×4 upstream against ×1 in the port** is the shared-factory case: `lib/main.rb#shortcut_item` is one constructor called from four sites.
- **Every `lib/conversion_row.rb` count doubles** — the class is a repeater with a fixed count of 2.
- **`Gtk::Builder` in `lib/conversion_row.rb`** stands for one `Gtk::Entry` the scan credits to a builder document, not to a widget method.
- **The port's menu is `Gio::Menu`, which no `.blp` keyword scan reports** on either side; upstream's `menu primary_menu` block is three `item` entries counted by hand.
- **`Adw.Application` appears as kind `type`, not `widget`**, on both sides, so the `Gtk::Application` substitution does not show up in the widget stream at all.
