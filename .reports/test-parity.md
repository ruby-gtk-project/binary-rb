# Test parity — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `4b4300e` |
| Upstream tests | **0** |
| Ported | 0 |
| Gaps | 0 |
| Test command | `rake test` (depends on `translations` and `schemas`) |
| Suite run | **yes**, round 2 — `rake test`: **24 runs, 62 assertions, 0 failures, 0 errors, 0 skips** |
| Driven suite run | **yes**, round 2 — `rake drive`: `test/drive_window.rb` **54 of 54 checks passed**, `test/drive_translated.rb` **8 of 8 checks passed** |
| How they were run | inside `nix develop`, under `xvfb-run -a`, going straight to rake's `exe` with `GEM_HOME` set and `BUNDLE_GEMFILE` unset — the shell's wrapped `rake`/`bundle` cannot start (FINDINGS.md sections 10 and 11) |

Upstream has no test suite. Verified: the census
(`.claude/skills/test-parity/scripts/test-census.sh`) over the extracted
`origin/main` tree returns **zero rows**; there is no `test/` or `tests/`
directory; `find . -iname '*test*'` matches nothing; `meson.build`,
`src/meson.build`, `data/meson.build` and `po/meson.build` declare no `test()`
target; and there is no `def test_`, `unittest`, `pytest`, `#[test]`,
`Test.add_func` or `it(...)` anywhere in `src/`.

Parity is **0/0 and is met trivially.**

**The port therefore inherits no safety net.** Every check listed under
`## Extra` was written for the port and pins nothing the original authors
thought worth pinning. Nothing in the upstream repository records which edge
case bit them, which bug came back, or why `get_answer` returns the string
`"char_dual"` rather than raising — the port's tests are the first tests this
app has ever had, and where they are wrong there is nothing to contradict them.

Do not build empty tables below this line.

## Round 2 — the suites were run

Both ran green, and running them changed two things about this ledger.

- The driven count in the first draft was 43 checks, and one of them —
  "entries carry an accessible label" — **could never have passed**:
  `gtk_test_accessible_*` reads GTK's test accessibility backend and nothing
  set `GTK_A11Y=test`, so it returned `false` whatever the widget carried. The
  entries were correct the whole time; the assertion was lying. Fixed in
  `test/environment.rb`.
- `test/drive_window.rb` is now 54 checks, 11 of them new this round: the
  About dialog's release notes and version and that it is a fresh instance per
  activation with the right transient parent, the preferences dialog's
  geometry, `--help` listing `-w, --new-window` and GLib rejecting an
  undeclared option, the `handle-local-options` return values, typing into the
  output entry on a freshly opened window, and `require "binary"` reaching the
  real application.

## Extra

The assertion unit is `check`, not `step`:
`test/gtk_driver.rb:78` increments `@checks` inside `check` and `step`
(`test/gtk_driver.rb:70`) only registers a block. Censusing on `step` would
over-count by 39.

| File | Unit | Count | What it covers |
|---|---|---:|---|
| `test/test_converter.rb` | `def test_*` | 12 | `Converter.answer` and `Converter.bit_count` — base conversion, the `char`/`char_dual` sentinels, equal bases, the fractional-part refusal, the non-decimal `bit_count` quirk |
| `test/test_i18n.rb` | `def test_*` | 7 | `_`, `d_`, `c_` and `n_` against the real `.mo` catalogues, including the `%(name)d` placeholder rewrite and the "Number base" domain that no catalogue defines |
| `test/test_settings.rb` | `def test_*` | 3 | the GSettings wrapper against upstream's schema id and key names |
| `test/drive_window.rb` | `check` | 35 | drives the live window headlessly — defaults, binary→decimal, reverse typing, the error class and tooltip, base switching, case normalisation, the Other/spin path, base-36, persistence on close, all three dialogs, two and three windows, `--new-window` |
| `test/drive_translated.rb` | `check` | 8 | the same window under `LANGUAGE=de`, asserting translated placeholder, tooltips and plural forms |

**65 assertions over 22 unit tests and 43 driven checks. None of them is
parity work, all of it stays extra, and parity is a floor the port owes
upstream, not a ceiling on what the port may test.**

## What could not be checked

`rake test` was not run. `minitest` is declared (`Gemfile:74`) and locked
(`Gemfile.lock:48`) but is not installed in the shell this audit ran in;
`msgfmt`, `glib-compile-schemas` and `xgettext` are all absent too, and
`rake test` depends on the first two through `task test: %i[translations
schemas]` (`Rakefile:221`). So:

- the suite's green-ness is **unverified** in this session;
- `rake drive` (the 43 driven checks and the screenshots) is **unverified**;
- the German-locale assertions in `test/drive_translated.rb` are
  **unverified**, which matters because they are the only evidence anywhere
  that the inherited catalogues actually reach the screen.

A check that could not be run is not a check that passed. Whoever has a
working `nix develop` shell closes all three in a minute.
