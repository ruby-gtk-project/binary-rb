# Test parity — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `eff4fa3` |
| Upstream tests | **0** |
| Ported | 0 |
| Gaps | 0 |
| Test command | `rake test` (depends on `translations` and `schemas`); `rake drive` for the driven suites |
| Suite run | **yes**, round 3 — `rake test`: **24 runs, 62 assertions, 0 failures, 0 errors, 0 skips** |
| Driven suites run | **yes**, round 3 — `test/drive_window.rb` **54 of 54**, `test/drive_translated.rb` **8 of 8** |
| How they were run | inside `nix develop`, with `DISPLAY` pointing at an `Xvfb` from `nix shell nixpkgs#xvfb`, `BUNDLE_GEMFILE` unset, and `RUBYLIB` assembled from the flake's gems derivation |

Upstream has no test suite. Verified four ways against the extracted
`origin/main` tree: the census
(`.claude/skills/test-parity/scripts/test-census.sh`) returns **zero rows**;
there is no `test/` or `tests/` directory and `find -iname '*test*'` matches
nothing; `meson.build`, `src/meson.build`, `data/meson.build` and
`po/meson.build` declare no `test()` target; and there is no `def test_`,
`unittest`, `pytest`, `#[test]`, `Test.add_func` or `it(` anywhere under `src/`.

Parity is **0/0 and is met trivially.**

**The port therefore inherits no safety net.** Every check listed under
`## Extra` was written for the port and pins nothing the original authors
thought worth pinning. Nothing in the upstream repository records which edge
case bit them, which bug came back, or why `get_answer` returns the string
`"char_dual"` rather than raising — the port's tests are the first tests this
app has ever had, and where they are wrong there is nothing to contradict them.
Three of them encode upstream *bugs* as expected behaviour (`+5` doing nothing,
`10.1` erroring across bases, the `bit_count` decimal tail), which is the
correct call for a parity port and is also three places where a future upstream
fix will read as a port regression.

## Census of the port's own suite

`.claude/skills/test-parity/scripts/test-census.sh .` returns 131 rows. That
number is not the suite's assertion count: the driver
(`test/gtk_driver.rb`) exposes both `step` and `check`, the census collects
both, and only `check` increments the pass counter. Read at the right call
site:

| File | `step`s | `check`s (the assertion unit) | Run result |
|---|---:|---:|---|
| `test/drive_window.rb` | 37 | 54 | 54 of 54 passed |
| `test/drive_translated.rb` | 7 | 8 | 8 of 8 passed |
| `test/test_converter.rb` | — | 14 minitest methods | part of the 24 |
| `test/test_i18n.rb` | — | 7 minitest methods | part of the 24 |
| `test/test_settings.rb` | — | 3 minitest methods | part of the 24 |

`test/environment.rb`, `test/gtk_driver.rb` and `test/test_helper.rb` are
harness files and carry no cases; the census excludes `*driver*` and `*helper*`
by name, and reading them confirms there is nothing hidden there.

## Extra

- `test/test_converter.rb` — 14 cases on `Converter.answer` and
  `Converter.bit_count`, including the three reproduced upstream bugs and the
  `1_0` / `+5` / `-5` / `10.1` edges.
- `test/test_i18n.rb` — 7 cases on the Fiddle gettext binding: `dgettext`, the
  `\u0004` context key, `dngettext` plural selection, and the `%(name)d`
  placeholder rewrite.
- `test/test_settings.rb` — 3 cases on the GSettings wrapper under upstream's
  schema id.
- `test/drive_window.rb` — 54 checks driving the live window: both conversion
  directions, the error class and tooltip on each entry, case normalisation,
  the "Other" base spin button, base 36, the bit popover sum, the bit buttons
  going insensitive, base persistence across a close, the About dialog's
  release notes and per-activation construction, the second window, `--help`,
  an undeclared option, the local-options handler, and `require "binary"`.
- `test/drive_translated.rb` — 8 checks under `LANGUAGE=de`, asserting
  translated base names, the base and menu tooltips, the placeholder, the
  plural-correct bit counter, the invalid-input tooltip and the shortcuts
  dialog's contextual section title.

## Open items against the suite itself

These are not parity rows — upstream has no tests for them to fail against —
and they are the reason the numbers above took three rounds to produce.

1. **The suite cannot be run with the project's own toolchain.** The flake's
   wrapped `rake` dies in `Bundler::Dsl#gemspec` ("There are no gemspecs at
   /nix/store/…-gemfile-and-lockfile") because `flake.nix`'s `bundlerEnv` is
   fed the **root** `Gemfile` — kettle-jem's development bundle, which has a
   `gemspec` directive — instead of `nix/Gemfile`, which exists for exactly
   this purpose and lists only `adwaita` and `gtk4`. `FINDINGS.md` section 10
   records the symptom and stops short of the cause.
2. **The devShell has no display server.** `xvfb-run` and `Xvfb` are both
   absent from it. Every file in `test/` reaches `require 'adwaita'`, which
   initialises GTK and raises `Gtk::InitError` with no `DISPLAY`, so even the
   three pure-logic minitest files cannot run headless. The display used for
   the runs above came from outside the project.
3. **No check asserts the process exit status.** `test/drive_window.rb` step 35
   asserts that GLib names an undeclared option and says so, and never looks at
   what the process exits with — which is how
   `.reports/component-parity.md` gap 5 (`exe/binary` dropping GLib's return
   value) stayed invisible through two green rounds.
4. **No check pins the preferences dialog's *identity* across activations.**
   Steps 32–33 of `test/drive_window.rb` do that for About — "it is not an
   instance shown on an earlier window", "its parent is the window it was
   opened from". The preferences steps (`test/drive_window.rb:212-227`) check
   that a dialog is showing and that its geometry is upstream's 400×306/200,
   and never that a second activation produced a second dialog. That is how
   `.reports/component-parity.md` gaps 1 and 2 — one memoized
   `Adwaita::PreferencesDialog` and one memoized `Adwaita::ShortcutsDialog`,
   against upstream's fresh `PrefsWindow()` per activation — stayed invisible
   through two green rounds while the same question about About got three
   checks.
