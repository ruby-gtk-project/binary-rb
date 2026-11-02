# Component identification — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` (Python + blueprint) |
| Port | `ruby` @ `4b4300e` |
| Scan | `.claude/skills/component-identification/scripts/component-scan.sh` |
| Upstream rows | 47 |
| Port rows | 53 |

Upstream has declarative UI (`src/*.blp`), so Step 1 applies: the blueprint
files are the inventory and the unit list. Three declarative roots:

| Root | Kind | Unit |
|---|---|---|
| `template $BinaryWindow: Adw.ApplicationWindow` (`src/window.blp`) | template | the window |
| `template $PrefsWindow: Adw.PreferencesWindow` (`src/preferences.blp`) | template | preferences |
| `Adw.ShortcutsDialog shortcuts_dialog` (`src/shortcuts-dialog.blp`) | **named root, no template** | shortcuts |

Plus two units with no widget class of their own:

- the application class `BinaryApplication(Adw.Application)` in `src/main.py` — actions, accels, About, preferences entry point;
- the conversion library `src/lib/get_answer.py` + `src/lib/bit_count.py` — no widgets, pure behaviour.

## File mapping

```
src/window.py + src/window.blp                 -> lib/window.rb + lib/conversion_row.rb
src/preferences.py + src/preferences.blp       -> lib/main.rb  (#preferences_dialog)
src/shortcuts-dialog.blp                       -> lib/main.rb  (#shortcuts_dialog, #general_shortcuts, #shortcut_item)
src/main.py                                    -> lib/main.rb + exe/binary
src/lib/get_answer.py + src/lib/bit_count.py   -> lib/converter.rb
src/style.css + src/style-hc.css               -> lib/main.rb  (STYLE, HIGH_CONTRAST_STYLE heredocs)
data/io.github.fizzyizzy05.binary.gschema.xml  -> data/schemas/... + lib/settings.rb
(nothing upstream)                             -> lib/i18n.rb          — the gettext binding
(nothing upstream)                             -> lib/binary.rb + lib/binary/application.rb  — UNEXPLAINED EXTRA
```

The mapping is 2→2 for the window: upstream repeats the whole input/output
block twice inline in `window.blp`, and the port factors the repeat into
`ConversionRow`, instantiated twice from `lib/window.rb`. **Every
`lib/conversion_row.rb` count below is therefore doubled before comparing.**

## src/window.blp + src/window.py — the one window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `close-request` → `on_close` | 360×390 default, 360×294 minimum, title `"Binary"` (unmarked literal, both sides) |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | `show-title: false` |
| `Gtk.MenuButton` | 1 | — | — | `primary`, `open-menu-symbolic`, tooltip `_("Main Menu")`, menu-model `primary_menu` |
| `Gtk.WindowHandle` | 1 | — | — | |
| `Adw.Clamp` | 1 | — | — | max 600, tightening 1000 |
| `Gtk.Box` | 6 | `typing-label` (arrow box only) | — | content box, 2× dropdown-row box, arrow box, 2× popover box |
| `Gtk.CenterBox` | 2 | — | — | one per conversion half |
| `Gtk.DropDown` | 2 | `flat-dropdown` | `notify` → `change_input_base` / `change_output_base` | model is a 5-item `Gtk.StringList`, tooltip `_("Input Base")` / `_("Output Base")` |
| `Gtk.SpinButton` | 2 | — | `changed` → same handlers | range 2–36, snap-to-ticks, increments (1,2), `numeric`, `margin-start: 6`; revealed only for base "Other" |
| `Gtk.MenuButton` | 2 | `bitLbl`, `flat` | — | the bit counter; label set from `ngettext`, popover `in_bit_popover`/`out_bit_popover`; `sensitive` toggled by digit count; `visible` toggled by base == 2 |
| `Gtk.Popover` | 2 | — | — | `has-arrow: true` |
| `Gtk.Label` | 2 | — | — | the bit breakdown; wrap, word mode, max 30 chars |
| `Gtk.Entry` | 2 | `error` (dynamic), `monospace` (dynamic) | `changed` → `input_handler` / `output_handler` | placeholder `_("Enter numbers")`, accessible label `_("Enter numbers…")`, `enable-undo: false`, tooltip `_("Invalid input")` set dynamically |
| `Gtk.Image` | 1 | — | — | `vertical-arrows-symbolic`, normal size |

Repeaters: none at runtime — the two halves are written out twice in the
blueprint. Conditional: `in_spin`/`out_spin` visible only at dropdown index 4;
`in_bit_label`/`out_bit_label` visible only when their own dropdown is index 0.

Dynamic CSS: `error` (added on invalid input, removed on valid),
`monospace` (added while the entry is non-empty).

Menu model `primary_menu`: two sections, three items —
`_("New Window")`→`app.new-window`, `_("_Keyboard Shortcuts")`→`app.shortcuts`,
`_("_About Binary")`→`app.about`.

### Port: lib/window.rb + lib/conversion_row.rb

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adwaita::ApplicationWindow` | 1 | — | `close-request` → `on_close` | `lib/window.rb:229` |
| `Adwaita::ToolbarView` | 1 | — | — | |
| `Adwaita::HeaderBar` | 1 | — | — | |
| `Gtk::MenuButton` | 1 | — | — | `lib/window.rb:246` |
| `Gtk::WindowHandle` | 1 | — | — | |
| `Adwaita::Clamp` | 1 | — | — | |
| `Gtk::Box` | 8 | `typing-label` | — | `content_box`, `arrow_box`, + 3 per row × 2 |
| `Gtk::CenterBox` | 2 | — | — | 1 × 2 |
| `Gtk::DropDown` | 2 | `flat-dropdown` | `notify::selected` | 1 × 2 |
| `Gtk::SpinButton` | 2 | — | `changed` | 1 × 2 |
| `Gtk::MenuButton` (bit) | 2 | `bitLbl`, `flat` | — | 1 × 2 |
| `Gtk::Popover` | 2 | — | — | 1 × 2 |
| `Gtk::Label` | 2 | — | — | 1 × 2 |
| `Gtk::Entry` | 2 | `error`, `monospace` | `changed` | built from a `Gtk::Builder` XML string, `lib/conversion_row.rb:156` |
| `Gtk::Image` | 1 | — | — | |

Repeater: `ConversionRow` — one class, two instances (`lib/window.rb:310`, `:319`).

## src/preferences.blp + src/preferences.py — preferences

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesWindow` | 1 | — | — | title `_("Preferences")`, default 400×306, height-request 200; `set_transient_for(active_window)` in `src/main.py:85` |
| `Adw.PreferencesPage` | 1 | — | — | id `preferences`, **empty** |

Port: `lib/main.rb:212` builds `Adwaita::PreferencesDialog` + one
`Adwaita::PreferencesPage`. No size properties.

## src/shortcuts-dialog.blp — the shortcuts dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ShortcutsDialog` | 1 | — | — | named root, never instantiated anywhere in `src/` |
| `Adw.ShortcutsSection` | 1 | — | — | title `C_("shortcut window", "General")` |
| `Adw.ShortcutsItem` | 4 | — | — | New Window / Close Window / Show Shortcuts / Quit, actions `app.new-window`, `app.close-window`, `app.shortcuts`, `app.quit` |

**Upstream never builds this dialog.** It is compiled into
`src/binary.gresource.xml:8` and no Python code loads it, and `app.shortcuts`
is never created in `create_action` — so upstream's own
`_("_Keyboard Shortcuts")` menu item and its `Show Shortcuts` row are dead.
Port: `lib/main.rb:219` builds it and `lib/main.rb:27` installs the action.

## src/main.py — the application

| Component | Detail |
|---|---|
| Actions installed | `quit`, `about`, `preferences`, `close-window`, `new-window` — 5, all via the `create_action` helper, names are literals |
| Accelerators | `quit`=`<primary>q`, `close-window`=`<primary>w`, `new-window`=`<primary>n`. `about` and `preferences` have none |
| Main option | `add_main_option("new-window", b"w", NONE, NONE, "Open a new window", None)` — so `--new-window` / `-w` appear in `--help` |
| Flags | `Gio.ApplicationFlags.DEFAULT_FLAGS` + `do_handle_local_options` |
| `Adw.AboutDialog` | 1, built by `new_from_appdata("io/github/fizzyizzy05/binary/metainfo.xml", "5.4")` then `set_developers`, `set_designers`, `set_translator_credits(_("translator-credits"))`, `set_copyright` |
| `Gtk.Window` | `set_default_icon_name('io.github.fizzyizzy05.binary')` |
| Signals | `activate` (via `do_activate`) |

Port: `lib/main.rb` — 6 actions (adds `shortcuts` with `<primary>question`),
accels from the `ACTIONS` table (names are loop variables, so the scan's
`action` stream is empty for the port; read off `lib/main.rb:21`), flags
`:handles_command_line` plus a `command-line` handler, `Adwaita::AboutDialog`
populated field by field, plus `startup` → `Adwaita.init` + style and icon
installation (`lib/main.rb:63`).

## Stylesheets

| Upstream | Port | Rules |
|---|---|---|
| `src/style.css` | `lib/main.rb:244` `STYLE` heredoc | `.bitLbl`, `.flat-dropdown button:not(:checked):not(:hover)`, `.typing-label` |
| `src/style-hc.css` | `lib/main.rb:263` `HIGH_CONTRAST_STYLE` heredoc | `.typing-label { opacity: 0.75 }` |

Both heredocs are character-for-character the upstream files. Platform classes
in play and defined by GTK/libadwaita, not by either sheet: `error`,
`monospace`, `flat`.

## Extra in the port, not derived from any upstream file

- `lib/binary.rb` + `lib/binary/application.rb` — a second, parallel
  application class holding `Adwaita::ApplicationWindow`,
  `Adwaita::ToolbarView`, `Adwaita::HeaderBar` and an
  **`Adwaita::StatusPage`** under a different application id
  (`org.rubygtkproject.Binary`), with three unmarked English strings
  including `"The Ruby port has not been written yet."`. It is the gem's
  `require` entry point (`binary-rb.gemspec` → `lib/binary.rb`). No upstream
  component corresponds to it.
- `lib/i18n.rb` — the libc gettext binding via Fiddle. Upstream gets gettext
  from Python's stdlib, so this is plumbing with no upstream file, not an
  extra component.
