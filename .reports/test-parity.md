# Test parity — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` (re-fetched, unmoved) |
| Port | `ruby` @ `8fff731` (round 9's commit; `lib/`, `exe/`, `test/` unchanged since `040f859`) |
| Round | 10 |
| Upstream tests | **0** (re-confirmed this round: no `test/`/`tests/` dir in `git archive origin/main`, no `test()` target in any `meson.build`) |
| Ported | 0 of 0, met trivially |
| **Gaps in the port's own suite** | **0** — re-verified live again this round, not re-cited from round 8 |
| Suite executed this round | **yes**, every command below re-run live under `nix develop` this round |
| Verdict | **clean on this axis** — see `.reports/accountability-ensurance.md` for why the overall audit is not |

Re-run live this round, not copied from round 7: `nix develop --command
xvfb-run -a ruby test/run_tests.rb` gives **27 runs, 72 assertions, 0
failures, 0 errors, 0 skips** (unchanged); `nix develop --command xvfb-run -a
rake drive` gives `drive_window.rb` **214/214**, `drive_translated.rb`
**8/8**, `high_contrast_check.rb` **6/6**, all `DRIVE OK`
(214+8+6=228 — matching this round's own commissioned gate's check count and
failure count exactly; its "13 components" figure does not match anything
this port's documentation produces — see
`.reports/accountability-ensurance.md` finding 3, filed against the gate
figure rather than against this suite).

Upstream has no tests, so this axis is entirely about whether the port's own
suite — its only safety net — actually runs, actually passes, and actually
covers the behaviour the other two parity ledgers claim. A green suite is not
automatically a true one; round 5-6 found two checks that were green because
they pinned a port bug as the expected answer. Every number below was run
live this round, not copied from the previous report.

## What was executed, this round, live

| Command | Result |
|---|---|
| `nix develop --command xvfb-run -a ruby test/run_tests.rb` | **27 runs, 72 assertions, 0 failures, 0 errors, 0 skips** |
| `nix develop --command xvfb-run -a ruby -Ilib -Itest test/drive_window.rb` | **214 of 214 checks — `DRIVE OK`** |
| `nix develop --command xvfb-run -a ruby -Ilib -Itest test/drive_translated.rb` | **8 of 8 — `DRIVE OK`** |
| `nix develop --command xvfb-run -a ruby -Ilib -Itest test/high_contrast_check.rb` | **6 of 6 — `DRIVE OK`** |
| `nix develop --command rake -T` | lists every task; no Bundler error |
| `nix develop --command rubocop --version` | `1.92.2` |
| `nix develop --command bundle --version` | `Bundler version 2.7.2` |
| `nix develop --command rake build` | builds `pkg/binary-rb-0.1.0.gem`, compiles all 32 `.mo` and the GSettings schema |
| `nix develop --command rake drive` | runs **all three** drivers through `xvfb-run` — `drive_window.rb` 214/214, `drive_translated.rb` 8/8, `high_contrast_check.rb` 6/6, all `DRIVE OK` |
| `nix develop --command rubocop lib/ exe/ test/drive_window.rb test/test_converter.rb test/gtk_driver.rb binary-rb.gemspec Rakefile` | 17 files, **12 offences, all pre-existing**, all in `test/gtk_driver.rb` and the templated `binary-rb.gemspec`/`Rakefile`; `lib/` and `exe/` clean |
| `GSETTINGS_SCHEMA_DIR=/tmp/doesnotexist dbus-run-session -- xvfb-run -a ruby -Ilib exe/binary` (outside the driver, independent check) | aborts with GLib's "Settings schema … is not installed", matching the driver's own assertion |
| `dbus-run-session -- xvfb-run -a ruby -Ilib exe/binary nonsense-arg` (outside the driver) | `GLib-GIO-CRITICAL: This application can not open files.` |

Census: `test-census.sh .` returns rows across `test/test_converter.rb`,
`test/test_i18n.rb`, `test/test_settings.rb`, `test/drive_window.rb`,
`test/drive_translated.rb` and `test/high_contrast_check.rb` — the same six
files as round 6, with more rows in `drive_window.rb` (214 checks against
205).

---

## Round 6 gaps, closed and re-verified live rather than re-cited

### Gap 1 (round 5/6) — the green check that pinned the base-prefix defect

`test/test_converter.rb` no longer has `test_prefixes_int_would_not_accept_in_these_bases`;
`grep -n "0b1\|0o1\|0x1" test/test_converter.rb` shows assertions against the
Python-measured values (`'3'`, `'15'`, `'31'`) instead. Confirmed by reading
the file, not by trusting the "closed" label. This remains the most serious
test-parity defect this port has had — a wrong test reports a behaviour as
verified rather than leaving it unverified — and its closure is the one most
worth re-checking by hand every round, which this round did.

### Gap 2 (round 6) — `rake drive` ran two of the three drivers and could not run either

`Rakefile`'s `drive` task now runs all three drivers
(`test/drive_window.rb`, `test/drive_translated.rb`,
`test/high_contrast_check.rb`) through `xvfb-run -a ruby`, not bare `ruby`.
Measured directly this round: `nix develop --command rake drive` completes
all three, `DRIVE OK` each time, with the real checks counts quoted above.

### Gap 3 (round 3/6) — the project's own toolchain could not start in the dev shell

`flake.nix`'s `gems` `bundlerEnv` is built from `gemdir = ./nix`
(`nix/Gemfile`, which carries no `gemspec` directive) rather than the root
Gemfile. Measured this round with the **literal** invocation shape every
other instruction in this harness uses — `nix develop --command <thing>`,
not a shell function, not `unset BUNDLE_GEMFILE`:

```
$ nix develop --command rake -T          # lists every task
$ nix develop --command rubocop --version # 1.92.2
$ nix develop --command bundle --version  # Bundler version 2.7.2
$ nix develop --command rake build        # builds clean
$ nix develop --command rake drive        # all three drivers, DRIVE OK
```

Round 6's own "NEW this round" finding narrowed this gap to "an
exec-vs-shell-function mismatch in one invocation style", because at that
time `nix develop --command rake -T` still failed while the shell function
worked. That mismatch is gone: the direct, no-workaround invocation now
succeeds, so this is a real closure and not a narrower restatement of the
same bug. The devShell banner's `lint: rubocop` line is now also a true
claim, re-checked by running exactly what it prints.

### Gap 4 (round 5/6) — three coverage holes

All three closed, two of them this round:

1. **The installed-gem-with-no-schema failure path.** `test/drive_window.rb`
   steps `[85]`-`[88]` move `data/schemas/gschemas.compiled` aside, run
   `exe/binary` with `GSETTINGS_SCHEMA_DIR` unset under its own
   `dbus-run-session`, and assert a non-zero exit with GLib's specific
   message — then restore the compiled schema. Re-run live this round as
   part of the 214, and reproduced independently outside the driver (see the
   table above).
2. **`Converter::ABORT` driven at the window level.** `test/drive_window.rb`
   types a literal `+` into the input entry and changes the output base on
   it, asserting the port's `#change_output_base` goes on to update chrome —
   present in the 214, re-run.
3. **Base-prefixed input driven at the window level.** `test/drive_window.rb`
   steps `[17]`-`[22]` type `0b11`, `0o17` and `0x1F` into the window's own
   entry and assert the converted output with no `error` class — not only
   the `Converter`-unit assertions gap 1 fixed. Confirmed this round:
   `grep -n "0b1\|0o1\|0x1" test/drive_window.rb` finds the steps, and the
   live run passes them.

---

## What is not claimed

- **214 of 214 is not "every behaviour is covered."** It is the count this
  round's suite actually runs and actually passes, re-measured live. No
  claim is made about coverage this report has not itself checked a test
  exists for.
- **`rake lint` was not run as a Rake task this round** — `rubocop` was
  invoked directly, matching what the devShell banner tells a user to type.
  `rake lint`'s own recipe (`cops/`-aware) was not separately exercised; this
  is a narrower claim than "the lint task passes", worth naming rather than
  rounding up.
- **No upstream CI equivalent exists to compare against** — `.gitlab-ci.yml`
  and `.github/` in this tree are the port's own, not upstream's; upstream's
  `meson.build` has no `test()` target to inherit coverage expectations from.

## A green suite that was wrong, and why this round trusts the suite again

The same three deliberately-upstream-bug-reproducing checks from round 5/6
(`+5` aborting, `10.1` erroring across unequal bases, `bit_count`'s decimal
tail) are still present and still correct to keep — they pin upstream's
actual behaviour, not a port defect. Gap 1's fix is the one case this port
has had of the opposite shape, and it is closed and independently
re-measured against Python this round, not re-cited from round 6's text.
