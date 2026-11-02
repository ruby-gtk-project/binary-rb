# Porting status — binary-rb

Resume point for the next run. Upstream is the `origin/main` ref in this same
repository; read it with `git show origin/main:<path>`. The port lives on the
`ruby` branch and is written from scratch against upstream as the spec — the
upstream ref is never checked out and never merged.

| | |
|---|---|
| Upstream ref | `origin/main` @ `e96066b` |
| Port branch | `ruby` @ `5780a74` |
| Last audit round | 3 |
| Open gaps | **7** |
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
| `lib/settings.rb` | `data/io.github.fizzyizzy05.binary.gschema.xml` |
| `lib/i18n.rb` | `po/` catalogues, via C `gettext` through Fiddle |
| `exe/binary` | `src/binary.in` (launcher) |
| `data/**` | upstream `data/**`, shipped byte-identical |
| `COPYING` | upstream `COPYING`, shipped verbatim and packaged in the gem |
| `po/**` | upstream `po/**`, with the source references pointing at the port's own files |

The window and the conversion library had full parity after round 3. The
preferences, shortcuts and application units were brought into line in round 4:
each dialog has its file, each is built per activation, and the launcher exits
with GLib's status.

## Not started

No upstream user-facing component is without a Ruby counterpart. Every unit
listed in `.reports/upstream-components.tsv` has code behind it, and every one
of them now has a file of its own. What is outstanding is the gaps below.

## Open gaps

7 open, from the round-3 reports in `.reports/`. The last accountability pass
reported **not clean**. Eleven of the eighteen were closed in round 4; the
reports themselves have not been re-run since, so their numbering is kept and
the closed entries are marked rather than removed.

### `.reports/component-parity.md` — 3 open of 9

1. ~~`#preferences_dialog` is memoized~~ — closed round 4: built per
   activation, as upstream's `on_preferences_action` does.
2. ~~`#shortcuts_dialog` is memoized~~ — closed round 4, the same way.
3. The `<primary>question` accelerator for `app.shortcuts` is invented by the
   port (see Blockers — the action itself is a deliberate divergence).
4. The application uses `:handles_command_line` instead of
   `Gio.ApplicationFlags.DEFAULT_FLAGS`, so a stray non-option argument is
   silently accepted where upstream rejects it.
5. ~~`exe/binary` discards GLib's exit status~~ — closed round 4: it exits with
   it, and the driver asserts 1 for a rejected option and 0 for `--help`.
6. Nothing installs `.desktop`, `.service` or metainfo; `@bindir@` is never
   substituted, so D-Bus activation is broken.
7. ~~The gem ships no `COPYING`/`LICENSE.md`~~ — closed round 4: upstream's
   `COPYING` is committed and packaged.
8. ~~`locale/` is absent from `spec.files`~~ — closed round 4: the gemspec globs
   `locale/**/*` and `rake build` depends on `:translations`, so a packed gem
   always carries the 32 compiled catalogues.
9. ~~The About, preferences and shortcuts units have no `lib/*.rb` of their
   own~~ — closed round 4: `lib/about_dialog.rb`, `lib/preferences_dialog.rb`
   and `lib/shortcuts_dialog.rb`.

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

### `.reports/test-parity.md` — 2 open of 4

Upstream has **no test suite**, so test parity is 0/0 and met trivially. These
four are defects in the port's own suite, which is the only safety net the port
has. The two that remain are both in the dev shell, not in the suite.

14. The flake's wrapped `rake`/`bundle`/`rubocop` cannot start: `bundlerEnv` is
    built from the root `Gemfile` (kettle-jem's development bundle, which has a
    `gemspec` directive) instead of `nix/Gemfile`. Cause is in `flake.nix`;
    `FINDINGS.md` section 10 records only the symptom.
15. The devShell has no display server. `xvfb-run` and `Xvfb` are both absent,
    and every file in `test/` reaches `require 'adwaita'`, so even the three
    pure-logic minitest files cannot run. The round-3 display came from
    `nix shell nixpkgs#xvfb`, outside the project.
16. ~~No check asserts the process exit status~~ — closed round 4, with gap 5.
17. ~~No check pins the preferences or shortcuts dialog's *identity* across
    activations~~ — closed round 4: both dialogs are now opened, closed,
    reopened and compared against the first instance.

### `.reports/accountability-ensurance.md` — 1 open of 1

18. One binding-limitation record is carrying a gap it should not: the
    `:handles_command_line` flag choice (gap 4) is written up as a binding
    limitation rather than as a divergence. 7 further entries were rewritten
    this round, 2 were false positives, 9 were allowed.

### What did run, round 4

Inside `nix develop`, with a display from `nix shell nixpkgs#xvfb-run` (gap 15
— the devShell still has none):

- `test/test_*.rb` — 24 runs, 62 assertions, 0 failures, 0 errors, 0 skips
- `test/drive_window.rb` — 60 of 60 checks
- `test/drive_translated.rb` — 8 of 8 checks
- the `translations`, `schemas` and `pot` recipes, run by hand because the
  flake's wrapped `rake` cannot start (gap 14)
- `rubocop` 1.90.0 over `lib/`, `exe/`, `test/drive_window.rb`, the gemspec and
  the Rakefile — clean on all of them except six pre-existing offences in the
  templated parts of the gemspec and Rakefile. The wrapped `rubocop` cannot
  start either (gap 14); it was loaded out of the gems derivation directly.

Green suites are not parity; gaps 16 and 17 were two places where they were
green and wrong, which is why closing 1, 2 and 5 came with the checks that
would have caught them.

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
