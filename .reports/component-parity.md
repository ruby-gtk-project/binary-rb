# Component parity — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `4b4300e` |
| Units | 5 (window, preferences, shortcuts, application, conversion library) |
| Units with parity | **1 / 5** (conversion library — and see its caveats) |

**Round 2: the suites were run.** Inside `nix develop`, under `xvfb-run -a`:
`rake test` is 24 runs / 62 assertions / 0 failures, `rake drive` is 54 of 54
checks in `test/drive_window.rb` and 8 of 8 in `test/drive_translated.rb`, and
`rake translations`, `rake schemas` and `rake pot` all run. The tools were
never missing — the shell's wrapped `rake` cannot start and GTK needs a
display, both written up in `FINDINGS.md` sections 10 and 11. Seven of this
document's gaps were closed in the same round: the About dialog's release
notes and its per-activation construction, the preferences geometry, the
registered `--new-window` main option, the input-validation divergences on
`1_0` and `+5`, the scaffold application on the gem's entry point, and the
nine msgids `xgettext` could not see.

The first draft's note, kept for the record: checks that **did not run** in
that environment, and so were not reported as passed: Step 5 (driving the
signals) and the screenshot comparison.

---

## Unit: the window — `src/window.blp` + `src/window.py` → `lib/window.rb` + `lib/conversion_row.rb`

`lib/conversion_row.rb` counts are doubled: the class is instantiated twice
(`lib/window.rb:310`, `lib/window.rb:319`).

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | ✓ `close-request` | ✓ | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Gtk.MenuButton` (menu) | 1 | 1 | — | — | ✓ `Main Menu` | parity |
| `Gtk.WindowHandle` | 1 | 1 | — | — | — | parity |
| `Adw.Clamp` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 6 | 8 | ✓ `typing-label` | — | — | explained extra: `ConversionRow#container` wraps each half's CenterBox + Entry, which upstream puts straight into the content box. Spacing 6 is preserved either way |
| `Gtk.CenterBox` | 2 | 2 | — | — | — | parity |
| `Gtk.DropDown` | 2 | 2 | ✓ `flat-dropdown` | ✓ `notify::selected` narrows upstream's bare `notify` | ✓ `Input Base`, `Output Base` | parity |
| `Gtk.SpinButton` | 2 | 2 | — | ✓ `changed` | — | parity |
| `Gtk.MenuButton` (bit) | 2 | 2 | ✓ `bitLbl`, `flat` | — | ✓ plural | parity |
| `Gtk.Popover` | 2 | 2 | — | — | — | parity |
| `Gtk.Label` | 2 | 2 | — | — | — | parity |
| `Gtk.Entry` | 2 | 2 | ✓ `error`, `monospace` | ✓ `changed` | ✓ | parity |
| `Gtk.Image` | 1 | 1 | — | — | — | parity |

Menu model: 3 items upstream, 3 in `lib/window.rb:261`–`:272`, same labels and
same action names. parity.

Stylesheet: `.bitLbl`, `.flat-dropdown button:not(:checked):not(:hover)` and
`.typing-label` are byte-identical between `src/style.css` and
`lib/main.rb:244`; `src/style-hc.css` is byte-identical to
`lib/main.rb:263` and is keyed on `Adwaita::StyleManager#high_contrast?`
(`lib/main.rb:151`) rather than on `Adw.Application`'s resource auto-loading.
Both classes are attached. Clean.

Messages: 14 upstream in this unit, 14 in the port. Clean.

**Gap 1 — the `bits` label.** `src/window.py:52` carries
`bits_text = _("bits")`. The port has no `_('bits')` anywhere
(`grep -rn bits lib/` finds only the plural forms). The variable is dead
upstream, but the msgid reached `po/binary.pot:90` and is translated in all
32 catalogues, and the port no longer emits it. Also open in
`.reports/translation-parity.md`.

**Gap 2 — the first-launch reverse-typing guard.** Upstream leaves the class
attribute `editable = False` (`src/window.py:65`) after `__init__`; the port
sets `@editable = true` at the end of `restore_bases` (`lib/window.rb:224`).
On upstream, typing into the *output* entry before any base change is swallowed
by `output_handler`'s `if self.editable == True` guard; on the port it converts
immediately. Behaviour difference on first launch, in the port's favour but
undeclared.

**Gap 3 — the swallowed-exception behaviour.** Upstream wraps
`change_input_base`, `change_output_base`, `input_handler` and
`output_handler` in bare `try/except: return` (`src/window.py:90`, `:100`),
so anything that raises leaves the UI untouched. `lib/window.rb` has no
equivalent. Two user-visible consequences, from reading
`src/lib/get_answer.py:51`:

- `+5` — upstream's `if '+' in input: split_input('')` calls a list, raises
  `TypeError`, the except swallows it and **nothing happens**. The port's
  `Converter.valid?` rejects `+` and shows the `error` class and the
  `Invalid input` tooltip.
- `1_0` in base 2 — Python's `int("1_0", 2)` accepts the underscore separator,
  so upstream's validity check passes and it converts to `2`. The port's
  `Converter.valid?` (`lib/converter.rb:33`) is a digit-class regex and
  rejects it, showing an error.

Both are the port diverging from what a user sees today. Neither is recorded
anywhere in the port.

---

## Unit: preferences — `src/preferences.blp` + `src/preferences.py` → `lib/main.rb#preferences_dialog`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.PreferencesWindow` | 1 | 1 (`Adwaita::PreferencesDialog`) | — | — | ✓ `Preferences` | correspondence — `AdwPreferencesWindow` is deprecated in favour of `AdwPreferencesDialog`; substitution recorded |
| `Adw.PreferencesPage` | 1 | 1 | — | — | — | parity |

**Gap 4 — the window geometry.** Upstream sets `default-width: 400`,
`default-height: 306` and `height-request: 200`
(`src/preferences.blp:6`–`:8`). `lib/main.rb:212`–`:217` sets none of the
three, so the preferences dialog opens at libadwaita's default size instead of
the one upstream chose.

---

## Unit: shortcuts — `src/shortcuts-dialog.blp` → `lib/main.rb#shortcuts_dialog`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | — | — | — | parity |
| `Adw.ShortcutsSection` | 1 | 1 | — | — | ✓ `shortcut window`/`General` | parity |
| `Adw.ShortcutsItem` | 4 | 4 (loop, `lib/main.rb:229`) | — | — | ✓ all four | parity |

Actions: `app.new-window`, `app.close-window`, `app.shortcuts`, `app.quit` —
all four present and spelled identically.

Explained extra: upstream compiles this dialog into its GResource
(`src/binary.gresource.xml:8`) and **never instantiates it**, and never creates
the `app.shortcuts` action, so upstream's own `_Keyboard Shortcuts` menu item
does nothing. The port creates the action (`lib/main.rb:27`), builds the
dialog, and adds an accelerator `<primary>question` that exists nowhere
upstream. Recorded as a deliberate improvement over an upstream defect, not a
gap. Worth reporting to upstream.

---

## Unit: the application — `src/main.py` → `lib/main.rb` + `exe/binary`

| Component | Up | Port | Verdict |
|---|---|---|---|
| Actions | 5 (`quit`, `about`, `preferences`, `close-window`, `new-window`) | 6 — the five plus `shortcuts` | explained extra (above) |
| Accelerators | `<primary>q`, `<primary>w`, `<primary>n` | the same three plus `<primary>question` | explained extra |
| `Gtk.Window.set_default_icon_name` | ✓ | ✓ `lib/main.rb:188` | parity |
| About dialog | `Adw.AboutDialog` | `Adwaita::AboutDialog` | **gaps 5 and 6** |
| Preferences entry point | `set_transient_for` + `present` | `present(active_window)` | parity |
| `--new-window` / `-w` | `add_main_option(...)`, `do_handle_local_options` | raw `ARGV` scan in the `command-line` handler | **gap 7** |

**Gap 5 — the About dialog's release notes.** Upstream builds About with
`Adw.AboutDialog.new_from_appdata("…/metainfo.xml", "5.4")`
(`src/main.py:71`), which sets `release-notes-version` and `release-notes`
from the `<release version="5.4">` block of the metainfo — so upstream's About
dialog has a **What's New** section listing "Binary now uses the system's
monospace font by default" and "The keyboard shortcuts view has been ported to
AdwShortcutsDialog (Laurie Turnbull)". `lib/main.rb:192`–`:208` populates the
dialog field by field and sets neither property. The port's About dialog has no
What's New section at all.

**Gap 6 — About is memoized and upstream's is not.** `src/main.py:70` builds a
fresh `Adw.AboutDialog` on every activation of `app.about`;
`lib/main.rb:193` memoizes one into `@about_dialog` and re-presents it. The
port's drive suite asserts it reopens (`test/drive_window.rb:149`), which is
the right thing to assert, but one memoized dialog shared by every window is
not what upstream does and the second window presenting it is untested
state-sharing. Recorded as a divergence to resolve, not waved through.

**Gap 7 — `--help` does not document `--new-window`.** Upstream registers the
option with GLib (`src/main.py:46`), so `binary --help` lists
`-w, --new-window   Open a new window` and GLib rejects unknown options. The
port has no `add_main_option` call; `lib/main.rb:84` scans `ARGV` for the two
strings by hand. `binary --help` therefore documents nothing, and
`binary --nonsense` is silently treated as a bare launch.

---

## Unit: conversion library — `src/lib/get_answer.py` + `src/lib/bit_count.py` → `lib/converter.rb`

No widgets. Behaviour compared by reading, line by line:

| Behaviour | Verdict |
|---|---|
| `"char"` / `"char_dual"` sentinels | parity |
| space anywhere → `char` | parity |
| leading `-` → `char` | parity |
| equal bases → echo the input | parity |
| single part → `calc_numerator`, uppercase letters above 9 | parity |
| a `.` in the input → `char` unless bases are equal | parity (faithful to upstream never implementing fractions) |
| `bit_count` partial string when the input is not decimal, trailing `" + "` kept | parity — the port reproduces the quirk at `lib/converter.rb:59` |
| `bit_count("")` → `""`, `bit_count("0")` → `"= 0"` | parity |
| `+` in the input | **gap 3** |
| `_` digit separators accepted by Python's `int()` | **gap 3** |

---

## Unexplained extra — `lib/binary.rb` + `lib/binary/application.rb`

A second application class with its own `Adwaita::ApplicationWindow`,
`Adwaita::ToolbarView`, `Adwaita::HeaderBar` and `Adwaita::StatusPage`, under
the application id `org.rubygtkproject.Binary`, whose status page reads
`"The Ruby port has not been written yet."`. It corresponds to no upstream
component, it carries three unmarked English strings, and it is what
`require "binary"` loads — `binary-rb.gemspec` points the gem's entry point at
`lib/binary.rb`, which requires it. The real app is `exe/binary` →
`lib/main.rb`. Per the rule, an extra is explained in the ledger or removed;
this one should be removed and the gemspec pointed at the real application.
