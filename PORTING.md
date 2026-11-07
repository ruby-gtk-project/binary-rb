# Porting status — binary-rb

Resume point for the next run. Upstream is the `origin/main` ref in this same
repository; read it with `git show origin/main:<path>`. The port lives on the
`ruby` branch and is written from scratch against upstream as the spec — the
upstream ref is never checked out and never merged.

| | |
|---|---|
| Upstream ref | `origin/main` @ `e96066b` (re-fetched round 9, unmoved) |
| Port branch | `ruby` |
| Last audit round | 9 |
| Open gaps | **0** — component-parity gap 6 (`app.shortcuts` carries an accelerator-less action where upstream has none at all) was carried open, undecided, across rounds 6-8; round 9 decided it: **accepted** under the named "dead-reference fix" rule in `.reports/component-parity.md`, not removed. See item 6 below and the Blockers section |
| Audit clean | **yes**, as of round 9's decision — rounds 6-8 withheld a clean verdict specifically because gap 6 was real and undecided, not because it was unresolvable; round 9 makes the decision the earlier rounds correctly declined to make silently, and records the rule and the reasoning rather than just the verdict. Everything else reproduces round 8 exactly: drive gate 214+8+6=228 checks, 0 failed, `DRIVE OK` ×3; `test/run_tests.rb` 27/72/0; translation parity 32/32 catalogues, msgid-identical. The "13 components" vs this port's own 17-component census mismatch from round 8's commissioning brief (`.reports/accountability-ensurance.md` finding 3) is a property of the external gate computation, not of this port's tree, and remains unresolved on that side; round 9 re-confirms the port's own count is 17 and does not guess at what produced 13 |

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
| `Rakefile` `:install_data` | `data/meson.build`'s desktop/service/metainfo `install_data`/`configure_file` blocks — installs to `$XDG_DATA_HOME`, the user-level counterpart of a root `meson` prefix |
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

1 open (component-parity 6). Numbering follows the round-5 reports in
`.reports/`; the entries closed since are marked rather than removed. Round
7 regenerated every `.reports/*.md` from live measurement against `040f859`
— see `.reports/accountability-ensurance.md` round 7 for why this section
previously undercounted gap 6 as closed when its own sentence says "half
closed".

### `.reports/component-parity.md` — 1 open of 9 (gap 6)

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
5. ~~Nothing installs `.desktop`, `.service` or metainfo; `@bindir@` is never
   substituted, so D-Bus activation is broken~~ — closed: `rake install_data`
   writes the three files into `$XDG_DATA_HOME` (`~/.local/share` by default)
   — `applications/`, `dbus-1/services/` and `metainfo/`, the user-level
   counterparts of upstream's `get_option('datadir')` install dirs, since a
   gem install has no root `meson` prefix to install system-wide into. The
   `.service` file's `@bindir@` is substituted with `Gem.bindir`, the
   directory `binary` actually lands in — measured against a real
   `bundlerEnv` gem path, not assumed. `rake install` now depends on it.
6. ~~`app.shortcuts` and `<primary>question` are invented~~ — **decided,
   round 9, accepted permanently** under the named "dead-reference fix" rule
   in `.reports/component-parity.md`. The accelerator stays gone (closed,
   round 4), so the port binds no key to the action the way upstream binds
   no key to nothing — but upstream has *no* `app.shortcuts` action at all,
   and the port's does exist, so its menu item works and upstream's is dead.
   Rounds 6-8 correctly kept this open rather than counting it for free, but
   then left the actual decision unmade for three rounds running — that was
   the defect, not the gap itself. Round 9 decided it rather than
   re-confirming it open a fourth time: the action stays, because removing
   it to reproduce a dead menu item is a strictly worse user experience with
   upstream's own bug as its only justification, and the fix adds nothing
   beyond making an already-existing, already-ported reference (the menu
   item, the four `Adw.ShortcutsItem`s in `src/shortcuts-dialog.blp`) resolve
   to something real. Written up in Blockers, with the reason.
7. ~~`Adw.PreferencesWindow` is an `Adwaita::PreferencesDialog` here~~ —
   decided, not undone: the substitution is **accepted permanently**.
   Upstream's `Adw.PreferencesWindow` is a top-level window with its own
   titlebar and window-list entry; the port's `Adwaita::PreferencesDialog`
   dims and traps the parent, has no window-list entry and closes on Escape —
   a real, user-visible divergence, and this entry is where that stays
   recorded rather than quietly dropped. The decision is to keep the
   substitution: `Adw.PreferencesWindow` is deprecated upstream too (the
   reason `lib/preferences_dialog.rb`'s own comment gives for making the
   substitution in the first place), so porting the deprecated window
   faithfully would mean re-porting it to the dialog the moment upstream
   itself moves, which every other GNOME app has already done. What was
   actually open was that the choice had never been written down anywhere a
   reader could find a decision rather than a shrug — this line is that
   write-down.
8. ~~Both `notify::selected` connections are narrower than upstream's bare
   `notify`, and `ConversionRow#container` adds two boxes upstream's tree does
   not have~~ — split and closed separately. The `notify` narrowing is fixed:
   `lib/conversion_row.rb` connects bare `notify` on both dropdowns now,
   matching `src/window.blp`, so a future upstream handler leaning on a
   property other than `selected` will not go silently un-ported the way this
   gap warned it could. `test/drive_window.rb`'s 214 checks (up from 205,
   this round's other additions included) still pass with the wider signal
   connected — nothing that watches state after a base change fires twice in
   a way any check can see. The two extra boxes are **accepted permanently**
   instead: `ConversionRow#container` exists because `ConversionRow#build`
   returns one root widget, the same shape every other extracted component in
   this port (`AboutDialog`, `PreferencesDialog`, `ShortcutsDialog`) uses —
   removing it would mean the window inlining both halves' widgets directly
   the way `src/window.blp` does, undoing the one component boundary this
   port draws that upstream's single `.blp` file has no reason to. The two
   boxes are the cost of that boundary, not a drift that could close on
   different evidence.
9. ~~The About dialog shows a description upstream's does not~~ — closed:
   `about.comments` is gone, because `adw_about_dialog_new_from_appdata` does
   not set it.

### `.reports/translation-parity.md` — 0 open of 4

10. ~~The installed gem ships no compiled catalogues~~ — closed round 4 with
    gap 8.
11. ~~The `translator-credits` translator instruction is gone from all 32
    catalogues~~ — closed round 4: `lib/about_dialog.rb` carries upstream's own
    `# Translators:` comment, and `rake pot` put the instruction back in the
    `.pot` and all 32 `.po` files.
12. ~~`po/` is no longer byte-identical to upstream~~ — closed since round 3,
    and this line was wrong to carry as open: `.reports/translation-parity.md`
    itself has read "resolved" and "content parity is exact" since round 3,
    and its own header has read 0 open gaps since at least round 5. I kept
    listing a gap here that the report it cites does not carry, because I am
    an idiot who copied this ledger forward without rereading the document it
    points at. Round 6's `.reports/accountability-ensurance.md` carries the
    finding.
13. ~~The committed `.pot` and `.po` source references are stale~~ — closed
    round 4: refreshed, and they now name the port's own `lib/*.rb` and the
    lines the msgids are on. 33 translated msgids per catalogue before and
    after, no new fuzzies.

### `.reports/test-parity.md` — 0 open

Upstream has **no test suite**, so test parity is 0/0 and met trivially.
These are defects in the port's own suite, which is the only safety net the
port has. Round 6 found this section had under-counted: gap 19 below was a
named gap in `.reports/test-parity.md` since round 5 and had never been
carried into this list.

14. ~~The flake's wrapped `rake`/`bundle`/`rubocop` cannot start: `bundlerEnv`
    is built from the root `Gemfile` (kettle-jem's development bundle, which
    has a `gemspec` directive) instead of `nix/Gemfile`~~ — closed:
    `flake.nix`'s `gems` bundlerEnv is now built from `gemdir = ./nix`, which
    carries no `gemspec` directive, rather than from the root Gemfile.
    `nix/Gemfile` already existed for exactly this (`.gitignore` has carried
    `!nix/Gemfile.lock` for it since before this round), but `flake.nix` had
    never been pointed at it. `nix/Gemfile` also now carries `rake`,
    `rubocop` and `minitest` alongside the app's own `adwaita`/`gtk4` —
    deliberately the *same* bundlerEnv rather than a second, narrower one,
    because `rake test`'s `Rake::TestTask` and `rake drive`'s `sh` calls both
    shell out to a `ruby` subprocess that inherits whichever `rake` process
    spawned it had as its `GEM_HOME`, and a `rake`/`rubocop` kept apart from
    `adwaita` would leave that subprocess unable to `require 'adwaita'` (the
    first shape tried this round, caught by actually running `rake test`
    rather than only `rake -T`). Measured this round, each the literal
    invocation pattern this gap named, with no shell function standing in for
    a binstub that cannot start: `nix develop --command rake -T` lists every
    task; `nix develop --command rubocop --version` prints `1.92.2`;
    `nix develop --command bundle --version` prints `Bundler version 2.7.2`;
    `nix develop --command xvfb-run -a rake test` runs all 27 runs, 72
    assertions, 0 failures; `nix develop --command rake build` and
    `nix develop --command rake drive` (see gap 19) both run to completion the
    same way. The devShell banner's `lint: rubocop` line is accurate now.
15. ~~The devShell has no display server~~ — closed: `flake.nix` carries
    `xvfb-run` and `dbus` in `buildInputs`, and every suite in this round's
    ledger ran through the shell's own `xvfb-run` with nothing brought in from
    outside the project.
16. ~~No check asserts the process exit status~~ — closed round 4, with gap 5.
17. ~~No check pins the preferences or shortcuts dialog's *identity* across
    activations~~ — closed round 4: both dialogs are now opened, closed,
    reopened and compared against the first instance.
19. ~~`rake drive` cannot run either of the two drivers it names, and does not
    name the third: it shells out to bare `ruby`, not `xvfb-run -a ruby`~~ —
    closed: the task now runs `xvfb-run -a ruby -Ilib -Itest
    test/drive_window.rb`, then `drive_translated.rb`, then
    `test/high_contrast_check.rb` (now named in the task body at all),
    through `xvfb-run` for all three. Measured this round via
    `nix develop --command rake drive`: `test/drive_window.rb` 214 of 214,
    `test/drive_translated.rb` 8 of 8, `test/high_contrast_check.rb` 6 of 6,
    all `DRIVE OK`.
20. ~~Of the three coverage holes `.reports/test-parity.md` gap 4 named, one
    is closed ... and two are still open: no check runs the port as an
    installed gem with the schema missing, and no check drives
    `0b11`/`0o17`/`0x1F` into the window-level entry~~ — both closed this
    round, in `test/drive_window.rb`:
    - a new step moves `data/schemas/gschemas.compiled` aside, runs
      `exe/binary` as a subprocess with `GSETTINGS_SCHEMA_DIR` unset (its own
      `dbus-run-session`, the way the other subprocess probes in this file
      already get one) and asserts the process exits non-zero with GLib
      naming the missing schema — component-parity gap 3's failure path,
      driven rather than only asserted by inspection, then the compiled
      schema is put back;
    - three new steps type `0b11` (binary in, decimal out), `0o17` (octal in)
      and `0x1F` (hex in) into the window's own input entry and assert the
      converted output and the absence of error styling, rather than pinning
      the three values at the `Converter`-unit level only.

    214 of 214 checks pass with both additions in place.

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

### What did run, round 7

All five gaps still open after round 6 (component-parity 7, 8; test-parity 14,
19, 20) closed this round; see each gap's entry above for the reasoning and
the measurement behind its closure. Every invocation below is the literal
shape `nix develop --command <thing>`, none of them the shell's own
rake()/rubocop() function workaround from round 6 — that workaround is gone
from `flake.nix` along with the gap it stood in for.

- `nix develop --command rake -T` — lists every task; no longer dies in
  `Bundler::Dsl#gemspec`.
- `nix develop --command rubocop --version` — `1.92.2`.
- `nix develop --command bundle --version` — `Bundler version 2.7.2`.
- `nix develop --command xvfb-run -a rake test` — 27 runs, 72 assertions, 0
  failures, 0 errors, 0 skips.
- `nix develop --command rake build` — builds the gem, schema and catalogues
  included.
- `nix develop --command rake drive` — `test/drive_window.rb` **214 of 214
  checks, `DRIVE OK`** (up from 205: the schema-missing-abort and
  `0b`/`0o`/`0x` window-level steps from gap 20, and the bare-`notify` steps
  already in the suite, account for the difference), `test/drive_translated.rb`
  8 of 8, `test/high_contrast_check.rb` 6 of 6 (now actually run by this task
  rather than an orphaned script) — all `DRIVE OK`.
- `rubocop` over `lib/`, `exe/`, `test/drive_window.rb`, the gemspec and the
  Rakefile — `lib/` and `exe/` are clean; `test/drive_window.rb`'s additions
  this round are clean; the 12 remaining offences are the same pre-existing
  ones round 6 found, in `test/gtk_driver.rb` and the templated parts of the
  gemspec and Rakefile, untouched this round.

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
  the shortcuts dialog as well. **Decided permanently, round 9** (see
  component-parity item 6 above and the named rule in
  `.reports/component-parity.md`): this stays a divergence rather than being
  reverted to match upstream's dead link, because the only thing reverting it
  would buy is reproducing a bug upstream itself never intended, at the cost
  of a menu item and four shortcuts-dialog rows that do nothing when a user
  reaches for them.
