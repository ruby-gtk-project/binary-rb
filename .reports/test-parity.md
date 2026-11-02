# Test parity — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `ff54bec` |
| Round | 5 |
| Upstream tests | **0** |
| Ported | 0 of 0 |
| Ported-test gaps | 0 (met trivially) |
| **Gaps in the port's own suite** | **4** (2 new, 2 carried) |
| Suite executed this round | **yes** — see below |
| Verdict | **not clean** |

## Upstream has no tests

Re-verified against the `origin/main` tree extracted with `git archive`:
`.claude/skills/test-parity/scripts/test-census.sh` returns **zero rows**
(`.reports/upstream-tests.tsv` is empty, correctly); there is no `test/` or
`tests/` directory; `meson.build`, `src/meson.build`, `data/meson.build` and
`po/meson.build` declare no `test()` target; and `def test_`, `unittest`,
`pytest`, `#[test]` and `Test.add_func` appear nowhere under `src/`. Test
parity is **0/0 and met trivially**.

That is the whole of parity on this axis, and it is also why the rest of this
document matters: **the port inherits no safety net.** Every check in the
port's suite was written by the porter against the porter's own reading of
upstream, with nothing upstream to contradict it. Section "A green suite that
is wrong" below is that risk realised.

## The port's suite, and what was actually executed

Run this round, from the project root, every invocation through the fork's dev
shell and a virtual display exactly as the shell banner prints it:

| Command | Result |
|---|---|
| `nix develop --command xvfb-run -a ruby test/run_tests.rb` | **24 runs, 62 assertions, 0 failures, 0 errors, 0 skips** |
| `nix develop --command xvfb-run -a ruby test/drive_window.rb` | **202 of 202 checks passed — DRIVE OK**, 17 components |
| `nix develop --command xvfb-run -a ruby test/drive_translated.rb` | **8 of 8 — DRIVE OK** (German: plural bit count, translated tooltip, `shortcut window` section title) |
| `nix develop --command xvfb-run -a ruby test/high_contrast_check.rb` | **6 of 6 — DRIVE OK** |
| `nix develop --command xvfb-run -a ruby exe/binary --help` / `--nonsense` / `nonsense-argument` | exit 0 / 1 / still running at 60s |

Nothing in this report rests on a suite that was not run. The runtime gate
asked for — `drive_ok=true`, 202 passed, 0 failed, 17 components — is met.

Census of the port's own checks: `test-census.sh .` returns 131 rows across
`test/test_converter.rb`, `test/test_i18n.rb`, `test/test_settings.rb`,
`test/drive_window.rb`, `test/drive_translated.rb` and
`test/high_contrast_check.rb`. Row count is not assertion count — the driver
exposes both `step` and `check` and the census collects both.

---

## Gap 1. NEW — a green check that pins a defect

`test/test_converter.rb:54-57`:

```ruby
def test_prefixes_int_would_not_accept_in_these_bases
  assert_equal 'char', Converter.answer('0x1f', 16, 10)
  assert_equal 'char', Converter.answer('0b11', 2, 10)
end
```

The name is false and the assertions lock in a divergence. Python's `int()`
does accept the prefix matching the base it is given:
`int('0x1f', 16) == 31`, `int('0b11', 2) == 3` — measured, not recalled. So
upstream converts both and the port errors on both
(`.reports/component-parity.md` gap 1), and this check is the reason nobody
noticed: the suite is green **because** it asserts the wrong answer.

This is the most serious kind of finding this axis can produce. A missing test
leaves a behaviour unverified; a wrong test reports it as verified. Owed: fix
`Converter.valid?` first, then rewrite these two assertions to the values
`python3` prints, and add the equal-base case (`Converter.answer('0b11', 2, 2)`
must be `'0b11'`, not `'char_dual'`).

## Gap 2. NEW — `rake drive` runs two of the three drivers, and cannot run either

`Rakefile`:

```ruby
task drive: %i[translations schemas] do
  sh 'ruby -Ilib -Itest test/drive_window.rb'
  sh 'ruby -Ilib -Itest test/drive_translated.rb'
end
```

Two problems. `test/high_contrast_check.rb` is not in the list, so the only
coverage the high-contrast stylesheet has — a component that exists solely
because the port reimplements AdwApplication's automatic resource loading by
hand — is a script no recipe calls and CI could never run. And the recipe
shells out to bare `ruby`, not `xvfb-run -a ruby`, so even with gap 3 fixed it
would die on `Gdk::Display.default` being nil in the dev shell the project
ships. The banner's four `xvfb-run` lines are the real entry points; the Rake
task is a third path that works nowhere.

## Gap 3. CARRIED (round 3 gap 14) — the project's own toolchain cannot start

Measured this round:

```
$ nix develop --command rake -T
[!] There was an error parsing `Gemfile`: There are no gemspecs at
    /nix/store/hdkzax361308821n39k410ng7wynavm6-gemfile-and-lockfile.
    Bundler cannot continue.
 #  # Include dependencies from binary-rb.gemspec
 >  gemspec
```

`bundle` and `rubocop` fail identically. The cause is in `flake.nix`: the
`bundlerEnv` is built from the root `Gemfile` — kettle-jem's development
bundle, which carries a `gemspec` directive — instead of `nix/Gemfile`, and the
derivation that bundler is pointed at contains only the Gemfile and the lock,
no gemspec.

Consequences, all of them real today:

- `rake test`, `rake drive`, `rake lint`, `rake translations`, `rake schemas`
  and `rake pot` cannot be run in the dev shell. The catalogues and the
  compiled schema both exist in the tree only because those two recipes were
  run by hand out of the gems derivation.
- The shell banner's last line, `lint:          rubocop`, is a false claim:
  that command exits with a Bundler backtrace.
- There is no single command that runs the port's whole suite. `test/run_tests.rb`
  runs the three minitest files; the three drivers are three more invocations;
  nothing aggregates them and nothing fails the build if one regresses.

`FINDINGS.md` section 10 records the symptom and not the cause.

## Gap 4. CARRIED, now narrowed — coverage holes the 202 checks leave

Round 3's gap 15 (the devShell has no display server) is **closed**:
`flake.nix:96` ships `xvfb-run`, every command above ran through it, and
`PORTING.md` still listing it as open is itself a finding
(`.reports/accountability-ensurance.md`). What remains are three behaviours no
check exercises, each one a component-parity gap whose *unverified* status is a
test gap in its own right:

1. **No check runs the port as an installed gem.** Gap 3 in
   `.reports/component-parity.md` — a packed gem carries no compiled GSettings
   schema and `Gio::Settings.new` aborts the process — is invisible to a suite
   that always runs from a working tree where `rake schemas` has been run. A
   check that moves `data/schemas/gschemas.compiled` aside, unsets
   `GSETTINGS_SCHEMA_DIR` and runs `exe/binary` would have caught it.
2. **No check changes a base with a `+` in the entry.** `Converter::ABORT` is
   tested at the `Converter` level only, so the `change_output_base`
   divergence (`.reports/component-parity.md` gap 2) is untested on both
   sides of the behaviour it affects.
3. **No check covers base-prefixed input at the window level.** Gap 1 above
   is the unit-level half; nothing drives `0b11` into the entry and asserts
   the absence of the `error` class.

## A green suite that is wrong

Three checks deliberately encode upstream *bugs* as expected behaviour — `+5`
doing nothing, `10.1` erroring across bases, `bit_count`'s decimal tail. That
is the correct call for a parity port. Gap 1 is the same shape and is **not**
correct: it encodes a port bug as upstream behaviour. The difference between
the two is a measurement, and the measurement was not taken until this round.
Green suites are not parity.
