# Component parity — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `eff4fa3` |
| Units | 5 (window, preferences, shortcuts, application, conversion library) |
| Units with parity | **2 / 5** (the window, the conversion library) |
| Round | 3 |

**What was run this round, and it all ran.** Inside `nix develop`, with an
`Xvfb :9x` display and `RUBYLIB` built from the flake's gems derivation:

- `rake test` — **24 runs, 62 assertions, 0 failures, 0 errors, 0 skips**
- `ruby -Ilib -Itest test/drive_window.rb` — **54 of 54 checks passed**
- `ruby -Ilib -Itest test/drive_translated.rb` — **8 of 8 checks passed**
- `rake translations` (32 `.mo`), `rake schemas`, `rake pot` — all three run
- Screenshots written to `tmp/shots/` (23 files)

Two caveats on *how* they ran, both of which are gaps in their own right:

1. The flake's wrapped `rake`/`bundle`/`rubocop` still cannot start —
   `Bundler::Dsl#gemspec: There are no gemspecs at
   /nix/store/…-gemfile-and-lockfile`, because the flake's `bundlerEnv` is
   built from the **root** `Gemfile` (kettle-jem's development bundle, which
   has a `gemspec` directive) rather than from `nix/Gemfile`. `FINDINGS.md`
   section 10 describes the symptom; the cause is in `flake.nix`.
2. **`xvfb-run`/`Xvfb` is not in the devShell.** Every file in `test/` reaches
   `require 'adwaita'`, which initialises GTK, so even `test_converter.rb`,
   `test_i18n.rb` and `test_settings.rb` — pure logic, no widgets — cannot run
   without a display. The display used here came from `nix shell nixpkgs#xvfb`,
   not from the project. A suite the project cannot run is a suite the project
   does not have.

---

## Unit: the window — `src/window.blp` + `src/window.py` → `lib/window.rb` + `lib/conversion_row.rb`

`lib/conversion_row.rb` counts are doubled: the class is instantiated twice.

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | ✓ `close-request` | — | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Gtk.WindowHandle` | 1 | 1 | — | — | — | parity |
| `Adw.Clamp` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 6 | **8** | ✓ `typing-label` | — | — | extra ×2, explained below |
| `Gtk.CenterBox` | 2 | 2 | — | — | — | parity |
| `Gtk.DropDown` | 2 | 2 | ✓ `flat-dropdown` | ✓ `notify` → `notify::selected` | ✓ `Input Base`, `Output Base` | parity |
| `Gtk.SpinButton` | 2 | 2 | — | ✓ `changed` | — | parity |
| `Gtk.Entry` | 2 | 2 | ✓ `error`, `monospace` | ✓ `changed` | ✓ `Enter numbers`, `Enter numbers…` | parity |
| `Gtk.MenuButton` | 3 | 3 | ✓ `bitLbl`, `flat` | — | ✓ `Main Menu` | parity |
| `Gtk.Popover` | 2 | 2 | — | — | — | parity |
| `Gtk.Image` | 1 | 1 | — | — | — | parity |
| `Gtk.Label` | 2 | 2 | — | — | — | parity |
| `Gio.Menu` items | 3 | 3 | — | — | ✓ `New Window`, `_Keyboard Shortcuts`, `_About Binary` | parity |

**The two extra boxes are explained, not waved through.** `ConversionRow#container`
(`lib/conversion_row.rb:130`) is a `Gtk::Box.new(:vertical, 6)` wrapping each
half's `CenterBox` + `Entry`. Upstream puts all five of those children directly
in the content box (`src/window.blp:36-158`). Spacing renders the same (6
between the content box's three children and 6 inside each container), so this
is a factored repeat and not a visual divergence. It is recorded because an
unexplained extra is usually a widget standing in for one that was not
understood.

**Styling.** `lib/main.rb` `STYLE` is byte-identical to `src/style.css`;
`HIGH_CONTRAST_STYLE` is byte-identical to `src/style-hc.css`. Both verified by
extracting the heredocs and `diff`. The high-contrast sheet is installed at
`PRIORITY_APPLICATION + 1` and added/removed on
`Adwaita::StyleManager notify::high-contrast`, which is the keying
`AdwApplication` does from the resource path. `flat`, `error` and `monospace`
are platform classes and need no rule in either sheet.

**Behaviour, driven.** `test/drive_window.rb` exercises the live widget tree
and all 54 checks pass: typing binary → decimal, decimal → binary, the
invalid-input error class and tooltip on both entries, lower-case input
upper-casing itself, decimal → hex, the "Other" base spin button, base 36, the
bit-count popover sum, the bit buttons going insensitive on empty input, the
base selection surviving a close, and the second window. Screenshots
`tmp/shots/01`–`08`, `12`.

`notify` → `notify::selected` is the port narrowing the connection to the
property upstream's handler acted on, which is strictly better. Verified
against upstream's own consequence: upstream's bare `notify` fires during
`set_model` in `__init__`, so `editable` is already `True` before the user can
type — `lib/window.rb#restore_bases` matches that end state and
`test/drive_window.rb` pins it by typing into the *output* entry on a fresh
window.

**Verdict: parity.**

---

## Unit: preferences — `src/preferences.blp` + `src/preferences.py` → `lib/main.rb#preferences_dialog`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.PreferencesWindow` | 1 | 0 | — | — | ✓ `Preferences` | substitution → `Adwaita::PreferencesDialog`, recorded |
| `Adw.PreferencesPage` | 1 | 1 | — | — | — | parity |

Geometry: `src/preferences.blp:7-9` gives default 400×306 and height-request
200. `AdwDialog` has no default size, so `lib/main.rb:278-280` sets
`content_width`/`content_height` and a size request. `FINDINGS.md` section 6.
The substitution itself is the documented
`AdwPreferencesWindow` → `AdwPreferencesDialog` deprecation, and is a
correspondence.

**gap 1 — the dialog is shared between activations, and upstream's is not.**
`lib/main.rb:276` is `@preferences_dialog ||=`. `src/main.py:82-85` constructs
a new `PrefsWindow()` on **every** activation of `app.preferences` and
`set_transient_for`s it to whatever window is active. The port presents one
instance forever, re-parenting it to a different window each time. This is
exactly the divergence commit `eff4fa3` fixed for the About dialog — the
comment at `lib/main.rb:245-247` says "no dialog instance is ever shared
between two windows" and then the next method but one shares one. Nothing
drives it: `test/drive_window.rb` step 33 asserts the per-activation behaviour
for About and there is no equivalent step for preferences.

**gap 2 — `#shortcuts_dialog` is memoized the same way** (`lib/main.rb:286`),
for the same reason, with the same consequence. Upstream has no behaviour to
compare against here only because upstream never loads the dialog at all
(see the next unit), which makes this the port's own invention sharing its own
instance.

**Verdict: 2 gaps.**

---

## Unit: shortcuts — `src/shortcuts-dialog.blp` → `lib/main.rb#shortcuts_dialog`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | — | — | — | parity |
| `Adw.ShortcutsSection` | 1 | 1 | — | — | ✓ `shortcut window`/`General` | parity |
| `Adw.ShortcutsItem` | 4 | 4 (one factory, 4 call sites) | — | — | ✓ `New Window`, `Close Window`, `Show Shortcuts`, `Quit`, all with ctxt `shortcut window` | parity |

Actions targeted: `app.new-window`, `app.close-window`, `app.shortcuts`,
`app.quit` — all four match upstream. `Adwaita::ShortcutsItem.new(title, '')`
plus `#action_name=` is forced by the bindings (`FINDINGS.md` section 3) and is
a correspondence. Driven: `test/drive_window.rb` step 10 and
`test/drive_translated.rb` step 5 both open the dialog and assert it is on
screen, including under `LANGUAGE=de`; screenshots `tmp/shots/10`, `22`.

**gap 3 — the accelerator is invented.** `lib/main.rb:39` registers
`'shortcuts' => ['<primary>question']`. Upstream sets accelerators for exactly
three actions (`quit`, `close-window`, `new-window`, `src/main.py:35-39`) and
none for `about`, `preferences` or the `shortcuts` action it never creates. The
port's shortcuts dialog therefore shows a `Ctrl+?` chip beside "Show Shortcuts"
that no upstream build has ever shown, and `<primary>question` is now bound
where upstream leaves it free for the user. The *action* being created is a
divergence the port argues for in `FINDINGS.md` as fixing an upstream dead
menu item; the *accelerator* is argued for nowhere and appears in no document
until this line.

**Verdict: 1 gap.**

---

## Unit: the application — `src/main.py` → `lib/main.rb` + `exe/binary` + `lib/binary.rb`

| Component | Upstream | Port | Verdict |
|---|---|---|---|
| application class | `Adw.Application` | `Gtk::Application` + `Adwaita.init` on `startup` | correspondence, `FINDINGS.md` §1 |
| flags | `Gio.ApplicationFlags.DEFAULT_FLAGS` | `:handles_command_line` | **gap 4** |
| app id | `io.github.fizzyizzy05.binary` | same (`lib/main.rb:13`) | parity |
| default icon | `Gtk.Window.set_default_icon_name` | same (`lib/main.rb:220`) | parity |
| action `quit` + `<primary>q` | ✓ | ✓ | parity |
| action `about` | ✓ | ✓ | parity |
| action `preferences` | ✓ | ✓ | parity |
| action `close-window` + `<primary>w` | ✓ | ✓ | parity |
| action `new-window` + `<primary>n` | ✓ | ✓ | parity |
| action `shortcuts` | **absent** | present, + accel | gap 3 above |
| `--new-window` / `-w` main option | `add_main_option` + `do_handle_local_options` | `add_main_option` + `handle-local-options` + `command-line` | parity, driven (steps 34–36) |
| About dialog | `new_from_appdata(…, "5.4")`, fresh per activation | parsed out of the same metainfo file, fresh per activation | parity |
| stylesheets | loaded by `AdwApplication` from the GResource base path | two `Gtk::CssProvider`s keyed on `notify::high-contrast` | correspondence |
| `vertical-arrows-symbolic` | GResource | `Gtk::IconTheme` search path onto `data/icons` | correspondence |
| exit status | `sys.exit(main.main(VERSION))` | **dropped** | **gap 5** |

**gap 4 — the flags differ, and it changes what the app does with a stray
argument.** With `DEFAULT_FLAGS` and no `HANDLES_OPEN`, GApplication rejects a
non-option argument. With `:handles_command_line`, the port's
`#handle_command_line` (`lib/main.rb:116-122`) scans for `--new-window`/`-w`
and otherwise calls `app.activate`, so `binary 42` quietly opens a window.
Nothing in the port's documents mentions the flag change; `lib/main.rb:82-83`
explains why the flag was chosen and not what it costs.

**gap 5 — `exe/binary` throws away the exit status.** `exe/binary:22` is
`BinaryApp.new.tap(&:build).run`, and `#run` (`lib/main.rb:96`) returns
`app.run(...)`'s value into nothing. Upstream's entry point is
`sys.exit(main.main(VERSION))` (`src/binary.in:45`, `src/main.py:106`), so a
run that GLib failed — an undeclared option, for instance — exits non-zero
upstream and `0` here. `test/drive_window.rb` step 35 asserts GLib *names* the
unknown option; no check looks at the status, which is why this survived.

**gap 6 — nothing installs the application's data files.** The port ships
`data/io.github.fizzyizzy05.binary.desktop.in`,
`…metainfo.xml.in` and `…service.in`, all three byte-identical to upstream's,
and has no task that turns them into installed files. Upstream's
`data/meson.build` runs them through `configure_file` and `install_data`. The
Rakefile's complete task list is `translations`, `schemas`, `pot`, `drive`,
`lint`, `docs` and the default aggregator. Consequences a user sees: no entry
in the shell's app grid, no `New Window` desktop action, no AppStream metadata
on the software centre page, and `DBusActivatable=true` in a desktop file whose
`.service` counterpart was never installed — so D-Bus activation fails.
`@bindir@` in `…service.in:3` is never substituted by anything in the port.

**gap 7 — the gem ships no licence text.** Upstream carries `COPYING`, the
full GPL-3. The port has no `COPYING` and no `LICENSE.md`, while
`binary-rb.gemspec:18` declares `spec.licenses = ["GPL-3.0-or-later"]` and its
file list names `LICENSE.md` behind a `.select { File.exist? }` that drops it
silently (`binary-rb.gemspec:64-69`). A GPL-3 derivative distributed with no
copy of the licence.

**gap 8 — the gem ships no compiled catalogues.** `spec.files`
(`binary-rb.gemspec:71-82`) globs `lib`, `exe`, `data/**/*` and `po/**/*`.
`locale/` is in neither. `BinaryApp::LOCALE_DIRECTORIES`
(`lib/main.rb:46-49`) looks for `../locale` and then `/usr/share/locale`, so an
installed gem finds no `binary.mo` anywhere and runs in English in all 32
languages while `.reports/translation-parity.md` reports 30/30. See that
report's gap 1.

**Verdict: 5 gaps (4, 5, 6, 7, 8) plus gap 3 above.**

---

## Unit: conversion library — `src/lib/get_answer.py` + `src/lib/bit_count.py` → `lib/converter.rb`

| Behaviour | Upstream | Port | Verdict |
|---|---|---|---|
| base 2/8/10/16/36 conversion, digits → `A`–`Z` | `calc_numerator` | `Integer(input, base).to_s(out).upcase` | parity |
| space anywhere → `char` | ✓ | ✓ (checked first, as upstream) | parity |
| leading `-` → `char` | ✓ | ✓ | parity |
| `+` anywhere → handler dies mid-way | `TypeError` from `split_input('')` | `Converter::ABORT`, which the window does nothing with | parity (bug reproduced) |
| equal bases echo the input | ✓ | ✓ | parity |
| equal bases + invalid → `char_dual`, both entries flagged | ✓ | ✓ | parity |
| any `.` across unequal bases → `char` | ✓ (upstream's own `# TODO`) | ✓ | parity (bug reproduced) |
| `_` digit separators accepted (`1_0` in base 2 is 2) | Python `int()` | `Integer()`, same terms | parity |
| `bit_count`: binary place values, `= n` read as decimal, tail dropped for non-decimal | ✓ | ✓ | parity (bug reproduced) |

Checked by hand against upstream for `""`, `"0"`, `"1"`, `"2"`, `"12"`, `"1A"`,
`"1010"` — identical output in every case. Pinned by 14 cases in
`test/test_converter.rb`, all passing.

**Verdict: parity.**

---

## Summary of gaps

| # | Unit | Gap |
|--:|---|---|
| 1 | preferences | `#preferences_dialog` memoized; upstream builds a fresh `PrefsWindow` per activation |
| 2 | shortcuts | `#shortcuts_dialog` memoized for the same reason |
| 3 | shortcuts | `<primary>question` accelerator invented by the port |
| 4 | application | `:handles_command_line` instead of `DEFAULT_FLAGS`; stray arguments silently accepted |
| 5 | application | `exe/binary` discards GLib's exit status |
| 6 | application | nothing installs `.desktop`, `.service` or metainfo; `@bindir@` never substituted; D-Bus activation broken |
| 7 | application | no `COPYING`/`LICENSE.md` under a gemspec that declares GPL-3.0-or-later |
| 8 | application | `locale/` absent from `spec.files`; the installed gem is English-only |
| 9 | file layout | the About, preferences and shortcuts units have no `lib/*.rb` of their own — see `.reports/accountability-ensurance.md` entry 1 |

Two extras, both located and explained rather than removed: the two
`ConversionRow#container` boxes, and the `shortcuts` action itself
(`FINDINGS.md`, "Upstream bugs found while porting").
