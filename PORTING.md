# Porting status — binary-rb

Resume point for the next run. Upstream is the `origin/main` ref in this same
repository; read it with `git show origin/main:<path>`. The port lives on the
`ruby` branch and is written from scratch against upstream as the spec — the
upstream ref is never checked out and never merged.

| | |
|---|---|
| Upstream ref | `origin/main` @ `e96066b` |
| Port branch | `ruby` |
| Last audit round | 5 |
| Open gaps | **5** |
| Audit clean | **no** |

## Upstream

Binary is a single-window GTK4/libadwaita number-base converter: two stacked
base-selector-plus-entry rows that convert into each other live, with a
per-entry bit-count popover for binary. It is implemented in Python 3
(PyGObject) with Blueprint (`.blp`) UI definitions and a Meson + GResource
build. The spec lives on the `origin/main` ref.

## Done

Components implemented and believed complete.

| Port path | Upstream source |
|---|---|
| `lib/window.rb` | `src/window.blp`, `src/window.py` |
| `lib/conversion_row.rb` | `src/window.blp`, `src/window.py` (one half of the window; instantiated twice) |
| `lib/converter.rb` | `src/lib/get_answer.py`, `src/lib/bit_count.py` |
| `lib/main.rb` | `src/main.py` (application, actions, accelerators, CSS) |
| `lib/about_dialog.rb` | `src/main.py:70-78` (About) |
| `lib/preferences_dialog.rb` | `src/preferences.py`, `src/preferences.blp` |
| `lib/shortcuts_dialog.rb` | `src/shortcuts-dialog.blp` |
| `lib/main.rb` `STYLE` heredoc | `src/style.css` (verified byte-identical) |
| `lib/main.rb` `HIGH_CONTRAST_STYLE` heredoc | `src/style-hc.css` (verified byte-identical) |
| `lib/main.rb` `#install_styles` / `#install_icons` | `src/binary.gresource.xml` — no bundle by design, so the bundle's keying is done by hand: the base sheet stays on the display and the high-contrast one is added and removed as `AdwStyleManager:high-contrast` flips, and `vertical-arrows-symbolic` is reached through a `Gtk::IconTheme` search path instead of a resource path |
| `Rakefile`, `binary-rb.gemspec` | `meson.build`, `data/meson.build`, `src/meson.build`, `po/meson.build`, `subprojects/blueprint-compiler.wrap` — the build, not a component: `rake translations` and `rake schemas` are the two compile steps, and `rake build` depends on both so a packed gem carries the catalogues and the compiled schema |
| `lib/settings.rb` | `data/io.github.fizzyizzy05.binary.gschema.xml` |
| `lib/i18n.rb` | `po/` catalogues, via C `gettext` through Fiddle |
| `exe/binary` | `src/binary.in` (launcher) |
| `data/**` | upstream `data/**`, shipped byte-identical |
| `COPYING` | upstream `COPYING`, shipped verbatim and packaged in the gem |
| `po/**` | upstream `po/**`, with the source references pointing at the port's own files |

The window and the conversion library had full parity after round 3. The
preferences, shortcuts and application units were brought into line in round 4:
each dialog has its file, each is built per activation, and the launcher exits
with GLib's status. This round closed the five behavioural divergences round 5
found: the validity gate is the `int(x, base)` call it was supposed to be, the
output-base handler skips what upstream's exception skips, the application
carries upstream's flags and no invented accelerator, the About dialog shows no
field `new_from_appdata` would not set, and `rake build` compiles the schema a
packed gem needs to start at all.

## Not started

No upstream user-facing component is without a Ruby counterpart. Every unit
listed in `.reports/upstream-components.tsv` has code behind it, and every one
of them now has a file of its own. What is outstanding is the gaps below.

## Open gaps

5 open. Numbering follows the round-5 reports in `.reports/`; the entries
closed since are marked rather than removed, and the reports themselves have
not been re-run, so their own verdicts still read **not clean**.

### `.reports/component-parity.md` — 3 open of 9

1. ~~Base-prefixed input is rejected~~ — closed: `Converter.valid?` is now
   `Integer(part, base, exception: false)`, the call Python's `int(x, base)`
   corresponds to, so `0b11` on Binary, `0o17` on Octal and `0x1F` on
   Hexadecimal convert instead of flagging, and across equal bases they echo
   back unflagged. Ruby's own extra `0d` prefix is rejected in base 10, where
   `int()` rejects it. `test/test_converter.rb` carries the measured Python
   output for each case; the two assertions that pinned the defect are gone.
2. ~~`#change_output_base` does work upstream's exception skips~~ — closed:
   `#input_handler` hands `Converter::ABORT` back and `#change_output_base`
   skips `#refresh_chrome` and `@editable = true` on it, which is what
   upstream's bare `except: return` does when `input_handler` raises on a `+`.
3. ~~The installed gem has no GSettings schema, and aborts~~ — closed:
   `rake build` depends on `:schemas` as well as `:translations`, so
   `data/schemas/gschemas.compiled` is compiled before the gem is packed and
   the gemspec's `data/**/*` glob carries it. `exe/binary` already points
   `GSETTINGS_SCHEMA_DIR` at that directory.
4. ~~`:handles_command_line` accepts arguments upstream rejects~~ — closed:
   the application is built with `:default_flags`, upstream's flags, and the
   `command-line` handler is gone. `binary nonsense-argument` now fails with
   GLib's "This application can not open files." on stderr and exit 1 —
   measured, not the message the round-5 report quoted from memory — and
   `test/drive_window.rb` asserts both. `--new-window` still travels the route
   upstream's `do_handle_local_options` takes.
5. Nothing installs `.desktop`, `.service` or metainfo; `@bindir@` is never
   substituted, so D-Bus activation is broken. (Round-5 gap 5.)
6. ~~`app.shortcuts` and `<primary>question` are invented~~ — half closed: the
   accelerator is gone, so the port binds what upstream binds (nothing) and
   its shortcuts dialog shows the item blank the way upstream's would. The
   action itself stays, deliberately, so the menu item is not dead; see
   Blockers.
7. `Adw.PreferencesWindow` is an `Adwaita::PreferencesDialog` here — a
   top-level window upstream, a dialog inside the parent window in the port.
   The window class is deprecated, which is why the substitution was made, and
   it is a user-visible divergence: it dims and traps the parent, has no
   window-list entry and closes on Escape. `content-width`/`content-height`
   carry upstream's two default sizes and `height-request: 200` becomes a size
   request. Open as a divergence to accept or undo, not as missing work.
8. Both `notify::selected` connections are narrower than upstream's bare
   `notify`, and `ConversionRow#container` adds two boxes upstream's tree does
   not have. Nothing observable differs today.
9. ~~The About dialog shows a description upstream's does not~~ — closed:
   `about.comments` is gone, because `adw_about_dialog_new_from_appdata` does
   not set it.

### `.reports/translation-parity.md` — 1 open of 4

10. ~~The installed gem ships no compiled catalogues~~ — closed round 4 with
    gap 8.
11. ~~The `translator-credits` translator instruction is gone from all 32
    catalogues~~ — closed round 4: `lib/about_dialog.rb` carries upstream's own
    `# Translators:` comment, and `rake pot` put the instruction back in the
    `.pot` and all 32 `.po` files.
12. `po/` is no longer byte-identical to upstream, and round 2's ledger said it
    was.
13. ~~The committed `.pot` and `.po` source references are stale~~ — closed
    round 4: refreshed, and they now name the port's own `lib/*.rb` and the
    lines the msgids are on. 33 translated msgids per catalogue before and
    after, no new fuzzies.

### `.reports/test-parity.md` — 1 open of 4

Upstream has **no test suite**, so test parity is 0/0 and met trivially. These
four are defects in the port's own suite, which is the only safety net the port
has. The one that remains is in the dev shell, not in the suite.

14. The flake's wrapped `rake`/`bundle`/`rubocop` cannot start: `bundlerEnv` is
    built from the root `Gemfile` (kettle-jem's development bundle, which has a
    `gemspec` directive) instead of `nix/Gemfile`. Cause is in `flake.nix`;
    `FINDINGS.md` section 10 records only the symptom.
15. ~~The devShell has no display server~~ — closed: `flake.nix` carries
    `xvfb-run` and `dbus` in `buildInputs`, and every suite in this round's
    ledger ran through the shell's own `xvfb-run` with nothing brought in from
    outside the project.
16. ~~No check asserts the process exit status~~ — closed round 4, with gap 5.
17. ~~No check pins the preferences or shortcuts dialog's *identity* across
    activations~~ — closed round 4: both dialogs are now opened, closed,
    reopened and compared against the first instance.

### `.reports/accountability-ensurance.md` — 0 open of 1

18. ~~One binding-limitation record is carrying a gap it should not: the
    `:handles_command_line` flag choice is written up as a binding limitation
    rather than as a divergence~~ — closed with component-parity gap 4. The
    flag is gone, the `command-line` handler with it, and the comment on
    `#app` now says what `:default_flags` buys (GLib's refusal of a stray
    argument) instead of describing a choice as a constraint.

### What did run, this round

All inside `nix develop`, with the devShell's own `xvfb-run` (gap 15 is closed
in the shell itself — the flake carries `xvfb-run` and `dbus` now, and the
banner names every command):

- `test/run_tests.rb` — 27 runs, 72 assertions, 0 failures, 0 errors, 0 skips
- `test/drive_window.rb` — **205 of 205 checks, `DRIVE OK`**
- `test/drive_translated.rb` — 8 of 8, `DRIVE OK`
- `test/high_contrast_check.rb` — 6 of 6, `DRIVE OK`
- `rubocop` 1.90.0 over `lib/`, `exe/`, `test/drive_window.rb`,
  `test/test_converter.rb`, `test/gtk_driver.rb`, the gemspec and the
  Rakefile — `lib/`, `exe/` and the two touched test files are clean; the 12
  remaining offences are all pre-existing, in `test/gtk_driver.rb` and in the
  templated parts of the gemspec and Rakefile. The wrapped `rubocop` still
  cannot start (gap 14); the shell's `rubocop` function is what runs.

Two measurements worth keeping, because both contradicted a report written
from memory:

- a stray argument is refused with GLib's *"This application can not open
  files."*, not *"Application does not take command line arguments"*, and only
  when no other instance holds the app id — a second invocation that finds
  itself remote hands the argument on, which is why the driver gives that probe
  its own `dbus-run-session` bus.
- the 120s watchdog in `test/gtk_driver.rb` was not slack for a hung app: a
  healthy window run reached it on a cold machine and reported a timeout
  against a step that was fine. It is 420s now, overridable with
  `BINARY_DRIVE_TIMEOUT`.

Green suites are not parity — gaps 16 and 17 were two places where they were
green and wrong, and round 5's gap 1 was a third, where
`test/test_converter.rb` asserted the invented error state. Every closure this
round came with the check that would have caught it.

## Blockers

Things that cannot be ported, and why.

- **Meson + GResource + blueprint-compiler.** `src/binary.gresource.xml`,
  `src/meson.build`, `data/meson.build`, `data/icons/meson.build`,
  `po/meson.build` and `subprojects/blueprint-compiler.wrap` have no counterpart
  in a gem. Widgets are built in Ruby, CSS is a heredoc in `lib/main.rb`, and
  the icon comes from a `Gtk::IconTheme` search path.
- **`Adw.AboutDialog.new_from_appdata`** needs the metainfo XML inside a
  compiled GResource bundle, which the port does not build. The About dialog is
  populated field-by-field by hand instead, reading the shipped
  `data/io.github.fizzyizzy05.binary.metainfo.xml.in` directly.
- **`Adwaita::Application` is broken in the Ruby bindings**, so the port uses
  `Gtk::Application`. That loses libadwaita's automatic resource loading of
  `style.css` and `style-hc.css`, which is why both stylesheets are installed
  manually from heredocs.
- **`Gtk::Accessible#update_property` raises `NotImplementedError`** in the
  bindings (it cannot marshal its array argument), so the two entries'
  accessible labels are applied through a small `Gtk::Builder` XML document in
  `lib/conversion_row.rb` rather than in code.
- **`src/__init__.py` and `src/binary.in`** are Python packaging and launcher
  plumbing with no user-facing component. `exe/binary` covers the equivalent
  job.
- **Upstream's `app.shortcuts` action is never created** in `src/main.py`,
  although the menu and the shortcuts dialog both reference it, so strict parity
  would mean shipping a dead menu item. The port deliberately diverges: it
  creates the action. It binds no accelerator to it, because upstream binds
  none and because `Adw.ShortcutsItem` renders whatever the application has
  bound to the action it names — an invented accelerator would show up inside
  the shortcuts dialog as well.
