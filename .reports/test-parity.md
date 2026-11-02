# Test parity — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `4b4300e` |
| Upstream tests | **0** |
| Ported | 0 |
| Gaps | 0 |
| Test command | `rake test` (depends on `translations` and `schemas`) |
| Suite run in this session | **no** — see below |

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
