# Porting status — binary-rb

Resume point for the next run. Upstream is the `origin/main` ref in this same
repository; read it with `git show origin/main:<path>`. The port lives on the
`ruby` branch and is written from scratch against upstream as the spec — the
upstream ref is never checked out and never merged.

| | |
|---|---|
| Upstream ref | `origin/main` @ `e96066b` |
| Port branch | `ruby` @ `168781b` |
| Last audit round | 3 |
| Open gaps | **18** |
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
| `lib/main.rb` (About) | `src/main.py:70-78` — no file of its own; see gap 9 |
| `lib/main.rb` (preferences) | `src/preferences.py`, `src/preferences.blp` — no file of its own; see gap 9 |
| `lib/main.rb` (shortcuts) | `src/shortcuts-dialog.blp` — no file of its own; see gap 9 |
| `lib/main.rb` `STYLE` heredoc | `src/style.css` (verified byte-identical) |
| `lib/main.rb` `HIGH_CONTRAST_STYLE` heredoc | `src/style-hc.css` (verified byte-identical) |
| `lib/settings.rb` | `data/io.github.fizzyizzy05.binary.gschema.xml` |
| `lib/i18n.rb` | `po/` catalogues, via C `gettext` through Fiddle |
| `exe/binary` | `src/binary.in` (launcher) |
| `data/**` | upstream `data/**`, shipped byte-identical |
| `po/**` | upstream `po/**` — no longer byte-identical; see translation gap 3 |

Two of the five audited units have full parity: the window and the conversion
library. The other three (preferences, shortcuts, application) do not.

## Not started

No upstream user-facing component is without a Ruby counterpart. Every unit
listed in `.reports/upstream-components.tsv` has code behind it. What is
outstanding is not missing components but the gaps below, and the file layout
recorded as gap 9 — the About, preferences and shortcuts units exist only as
methods inside `lib/main.rb` and still owe `lib/about_dialog.rb`,
`lib/preferences_dialog.rb` and `lib/shortcuts_dialog.rb`.

## Open gaps

18 open, from the round-3 reports in `.reports/`. The last accountability pass
reported **not clean**.

### `.reports/component-parity.md` — 9

1. `#preferences_dialog` is memoized; upstream builds a fresh `PrefsWindow` per
   activation.
2. `#shortcuts_dialog` is memoized for the same reason.
3. The `<primary>question` accelerator for `app.shortcuts` is invented by the
   port (see Blockers — the action itself is a deliberate divergence).
4. The application uses `:handles_command_line` instead of
   `Gio.ApplicationFlags.DEFAULT_FLAGS`, so a stray non-option argument is
   silently accepted where upstream rejects it.
5. `exe/binary` discards GLib's exit status.
6. Nothing installs `.desktop`, `.service` or metainfo; `@bindir@` is never
   substituted, so D-Bus activation is broken.
7. The gem ships no `COPYING`/`LICENSE.md` under a gemspec that declares
   GPL-3.0-or-later.
8. `locale/` is absent from `spec.files`; the installed gem is English-only.
9. The About, preferences and shortcuts units have no `lib/*.rb` of their own.

### `.reports/translation-parity.md` — 4

10. The installed gem ships no compiled catalogues, so it is English in all 32
    languages (same root cause as gap 8).
11. The `translator-credits` translator instruction is gone from all 32
    catalogues.
12. `po/` is no longer byte-identical to upstream, and round 2's ledger said it
    was.
13. The committed `.pot` and `.po` source references are stale.

### `.reports/test-parity.md` — 4

Upstream has **no test suite**, so test parity is 0/0 and met trivially. These
four are defects in the port's own suite, which is the only safety net the port
has.

14. The flake's wrapped `rake`/`bundle`/`rubocop` cannot start: `bundlerEnv` is
    built from the root `Gemfile` (kettle-jem's development bundle, which has a
    `gemspec` directive) instead of `nix/Gemfile`. Cause is in `flake.nix`;
    `FINDINGS.md` section 10 records only the symptom.
15. The devShell has no display server. `xvfb-run` and `Xvfb` are both absent,
    and every file in `test/` reaches `require 'adwaita'`, so even the three
    pure-logic minitest files cannot run. The round-3 display came from
    `nix shell nixpkgs#xvfb`, outside the project.
16. No check asserts the process exit status, which is how gap 5 survived two
    green rounds.
17. No check pins the preferences or shortcuts dialog's *identity* across
    activations, which is how gaps 1 and 2 survived two green rounds.

### `.reports/accountability-ensurance.md` — 1

18. One binding-limitation record is carrying a gap it should not: the
    `:handles_command_line` flag choice (gap 4) is written up as a binding
    limitation rather than as a divergence. 7 further entries were rewritten
    this round, 2 were false positives, 9 were allowed.

### What did run, round 3

Inside `nix develop`, with an `Xvfb` display and `RUBYLIB` from the flake's
gems derivation:

- `rake test` — 24 runs, 62 assertions, 0 failures, 0 errors, 0 skips
- `test/drive_window.rb` — 54 of 54 checks
- `test/drive_translated.rb` — 8 of 8 checks
- `rake translations` (32 `.mo`), `rake schemas`, `rake pot` — all three ran

Green suites are not parity; gaps 16 and 17 are two places where they were
green and wrong.

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
  creates the action and gives it `<primary>question`. The invented accelerator
  is tracked as gap 3.
