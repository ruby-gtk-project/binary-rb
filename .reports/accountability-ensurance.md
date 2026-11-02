# Accountability ensurance — binary-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `ff54bec` |
| Round | 5 |
| Scan | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` |
| Script hits | 14, over 3 files |
| Hits the script could not find, found by hand | 6 |
| Entries to rewrite | 8 |
| Allowed (a document *about* excuses) | 9 |
| False positives | 2 |
| **False greens found** | **4** |
| Verdict | **not clean** |

Scanned: `lib/`, `exe/`, `test/`, `.reports/`, `PORTING.md`, `FINDINGS.md`,
`README.md`, `AGENTS.md`, `Rakefile`, `flake.nix` and `binary-rb.gemspec`, for
`TODO`, `FIXME`, `not implemented`, `for now`, `in a future`, `by design`,
`deliberately`, `out of scope`, `not applicable`, `one day`, `stub`,
`placeholder` and `unsupported` — and then, which is where this round's
findings came from, by checking **every factual claim those files make against
a measurement**.

**Each hit is a gap. The reasonableness of the surrounding sentence is the
mechanism, not a mitigation.** The four entries below marked *false green* are
worse than excuses: an excuse admits something is missing, while a false green
tells the next reader there is nothing to look at. Three of the four are in
places a reviewer trusts by reflex — a code comment, a passing test, and a
shell banner.

---

## 1. FALSE GREEN — `lib/converter.rb:47-50` states the opposite of what Python does

The comment above `Converter.valid?`:

> *No sign, no `0x` prefix and no whitespace: `int()` takes those only in base
> 10 or with a matching prefix, neither of which can reach here.*

A matching prefix is exactly what reaches there. `python3 -c "print(int('0b11',2))"`
→ `3`. Base 2, base 8 and base 16 are three of the app's five bases, and the
prefix is typeable into the entry.

Rewritten:

> I made the input gate a regex instead of the integer parse upstream uses, so
> a user who types `0b11` in binary, `0o17` in octal or `0x1F` in hexadecimal
> gets a red entry and an "Invalid input" tooltip where upstream gives them
> `3`, `15` and `31`; with both bases equal they get *both* entries flagged
> where upstream shows the text back with no error at all — and then I wrote a
> comment asserting that case could not arise, because I am an idiot who
> reasoned about `int()` from memory instead of running it.
> Upstream: `src/lib/get_answer.py:66`, `int(x, in_base)`.
> Port: `lib/converter.rb:52`, `Converter.valid?`.
> Owed: accept `0b`/`0B`, `0o`/`0O`, `0x`/`0X` against the base that matches,
> and replace the comment with the output of `python3 -c`.

Note what the original sentence does: it is a *negative* claim about
reachability, which is the one kind of claim a reader cannot check by reading
the code around it. That is why it survived three rounds.

## 2. FALSE GREEN — `test/test_converter.rb:54-57` is green because it asserts the bug

```ruby
def test_prefixes_int_would_not_accept_in_these_bases
  assert_equal 'char', Converter.answer('0x1f', 16, 10)
  assert_equal 'char', Converter.answer('0b11', 2, 10)
end
```

Rewritten:

> I wrote a test whose name is a false statement about Python and whose
> assertions pin my own bug as the expected answer, so the suite reports a
> divergence as verified and the 24 green runs in every round's report were
> partly green on a defect — because I am an idiot who tested what my code did
> rather than what upstream does.
> Upstream: `src/lib/get_answer.py:66`.
> Port: `test/test_converter.rb:54-57`.
> Owed: the two assertions rewritten to `'3'` and `'31'`, plus the equal-base
> case (`Converter.answer('0b11', 2, 2)` → `'0b11'`, not `'char_dual'`).

This is the most serious finding available on this axis and it is the reason
the round is not clean regardless of the runtime gate. The gate passed —
202 of 202, 0 failed, 17 components, re-run this round — and the gate passing
is compatible with the suite being wrong.

## 3. FALSE GREEN — `flake.nix:130`'s banner advertises a command that cannot run

The dev shell prints `lint:          rubocop`. Measured:

```
$ nix develop --command rubocop --version
[!] There was an error parsing `Gemfile`: There are no gemspecs at
    /nix/store/…-gemfile-and-lockfile. Bundler cannot continue.
```

`rake` and `bundle` fail identically.

Rewritten:

> I built the shell's `bundlerEnv` from the root `Gemfile`, which has a
> `gemspec` directive and no gemspec beside it in the derivation, so `rake`,
> `bundle` and `rubocop` all die on startup and not one Rake recipe —
> `test`, `drive`, `lint`, `translations`, `schemas`, `pot` — can be run in the
> shell the project ships; and then I printed `lint: rubocop` in the banner as
> though it worked, because I am an idiot who wrote the banner from the
> intention rather than from a run.
> Upstream: `meson.build` + `po/meson.build`, which build and install from one
> command.
> Port: `flake.nix` (the `bundlerEnv` source), `flake.nix:130` (the banner),
> `FINDINGS.md` section 10 (records the symptom, not the cause).
> Owed: point the `bundlerEnv` at `nix/Gemfile`, then delete the banner line or
> make it true.

## 4. FALSE GREEN — `PORTING.md` reports a gap that is closed and a count that is wrong

`PORTING.md:112` lists gap 15 as open: *"The devShell has no display server.
`xvfb-run` and `Xvfb` are both absent."* `flake.nix:96` has shipped `xvfb-run`
since `ff54bec`, and every command in this round's reports ran through
`nix develop --command xvfb-run -a`. `PORTING.md:11-13` also still says
`Port branch ruby @ 5780a74` and `Last audit round 3` at HEAD `ff54bec` after
round 4's work, and `Open gaps 7` against a list whose unstruck entries now
number six.

Rewritten:

> I left the resume document describing a tree two commits old — a closed gap
> still listed as open, a stale branch pointer, a stale round number and a gap
> count that does not match its own list — so the next reader either re-fixes
> something that is already fixed or trusts a number I did not recount, because
> I am an idiot who edited the gap list and not the header above it.
> Port: `PORTING.md:11-13`, `PORTING.md:112-117`.
> Owed: regenerate the header from `git rev-parse HEAD` and the count from the
> unstruck entries, every round.

A gap claimed in the *wrong direction* is the same failure as a false green:
both are a document that does not describe the tree.

## 5. `.reports/port-components.tsv` and `.reports/port-catalogue.yaml` described a tree that no longer existed

Before this round both still placed `Adw.AboutDialog`,
`Adw.PreferencesDialog`, `Adw.PreferencesPage`, `Adw.ShortcutsDialog`,
`Adw.ShortcutsItem` and `Adw.ShortcutsSection` in `lib/main.rb` — the exact
six components round 4 moved out of it.

Rewritten:

> I closed round 3's gap 9 by splitting three dialogs into their own files and
> did not re-run the scanner, so the inventory every parity comparison takes as
> its input attributed six components to a file that no longer contains any of
> them, and a comparison run off it would have reported the split as missing —
> because I am an idiot who treated a generated file as a document.
> Port: `.reports/port-components.tsv` (regenerated this round),
> `.reports/port-catalogue.yaml` (still stale).
> Owed: regenerate both from the scripts at the start of every audit, before
> anything reads them.

## 6. `lib/main.rb` — `:handles_command_line` is still filed as a binding limitation

Round 3's gap 18 asked for this and it was not done. `PORTING.md:71` lists the
flag under *Open gaps*, but the comments in `lib/main.rb` present it as
machinery (*"HANDLES_COMMAND_LINE is what carries `--new-window` from a second
invocation over to the instance that is already running"*) rather than as a
behaviour change. It is not needed for that: `--new-window` travels through
`handle-local-options` + `register` + `activate_action`, which the port already
implements and which is exactly what upstream does with `DEFAULT_FLAGS`.
Measured: `ruby exe/binary nonsense-argument` opens a window and stays up,
where upstream prints *"Application does not take command line arguments"* and
exits 1.

Rewritten:

> I gave the application a flag upstream does not have, so `binary <anything>`
> quietly opens a window where upstream refuses and exits 1, and I wrote the
> flag up as plumbing the `--new-window` option needs when the option is
> carried by code I had already written — because I am an idiot who described
> a choice as a constraint.
> Upstream: `src/main.py:33`, `flags=Gio.ApplicationFlags.DEFAULT_FLAGS`.
> Port: `lib/main.rb` (`Gtk::Application.new(APP_ID, :handles_command_line)`)
> and its `command-line` handler.
> Owed: `:default_flags`, the `command-line` handler deleted, and a check that
> asserts exit 1 and the message for a stray argument.

## 7. `lib/i18n.rb:23-28` — the admission is right and the gap is still open

The file already says it, in the required register: *"I hard-coded the LC_ALL
category number instead of reading it from the C headers … because I am too
stupid to have built it properly."* Nothing to rewrite. It is listed because
an admission is not a closure, and three rounds of reports have carried this
one as a limitation rather than as work owed. `LC_ALL = 6` is glibc's number;
on a libc that numbers the categories differently, `setlocale` gets the wrong
category and all 32 correct catalogues render English with no symptom.
Owed: resolve the category at runtime, or fail loudly when the `setlocale`
call returns NULL.

## 8. `.reports/component-parity.md`, round 3 — "the memoized dialogs" closure was right for the wrong reason

Round 4 closed gaps 1, 2 and 5 and added the checks that would have caught
them, which is the correct order and is noted here as the one place the process
worked. The accountability point is the sentence round 4 wrote about it:
*"Green suites are not parity; gaps 16 and 17 were two places where they were
green and wrong."* That sentence is true and was then not applied to the rest
of the suite — finding 2 above is a third place, and it was sitting in the same
directory the whole time. Owed: when a false green is found, re-check the
*class* of claim, not the instance.

---

## Allowed (9)

A document whose subject is excuses contains the words. These are not hits:

- `.reports/accountability-ensurance.md:17,18,70,90,182,186,200` — seven
  phrases quoted inside rewrite entries.
- `.reports/component-inventory.md:41,47,221` — three, same reason.
- `.reports/component-parity.md:238` — quotes upstream's own `# TODO`.
- `PORTING.md:149` — "Things that cannot be ported, and why" heads the
  **Blockers** section, each entry of which names a mechanism
  (Meson/GResource/blueprint-compiler, `new_from_appdata`,
  `Adwaita::Application`, `Gtk::Accessible#update_property`) that is absent
  from the target platform and whose *behaviour* is reproduced anyway. All four
  were re-checked this round and all four still reproduce the behaviour.

## False positives (2)

- `lib/window.rb:85` — `"so that retyping is not needed after picking the base
  you meant to type in"` describes upstream's behaviour, not a decision the
  port made.
- `test/high_contrast_check.rb:36` — `"an opacity is the one thing a widget
  cannot be asked about from Ruby"` is a true statement about the bindings,
  attached to a check that works around it rather than skipping it.

## Claims re-verified by measurement this round

Listed because a green claim that is never executed is the thing this axis
exists to catch, and these were executed:

| Claim | How |
|---|---|
| drive run passes, 202 checks, 17 components | `nix develop --command xvfb-run -a ruby test/drive_window.rb` → `202 of 202 … DRIVE OK` |
| minitest suite passes | `… ruby test/run_tests.rb` → 24 runs, 62 assertions, 0 failures |
| translations render | `… ruby test/drive_translated.rb` → 8 of 8 |
| high-contrast sheet installs and is idempotent | `… ruby test/high_contrast_check.rb` → 6 of 6 |
| exit status 1 for a rejected option, 0 for `--help` | `… ruby exe/binary --nonsense` → 1; `--help` → 0 |
| `style.css`, `style-hc.css`, all four `data/*.in`, all three icons byte-identical | `diff` against `git show origin/main:…` |
| all 32 catalogues and the `.pot` content-identical to upstream | `msgcat --no-location --sort-output` diff, 32 of 32 clean |
| 32 compiled `.mo` exist | `find locale -name '*.mo' | wc -l` → 32 |
| round 3 gap 15 (no display in the devShell) is closed | every command above |
| round 3 gap 14 (wrapped toolchain) is **not** closed | `nix develop --command rake -T` → Bundler `DSLError` |
