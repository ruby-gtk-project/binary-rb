# Accountability ensurance — binary-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` (re-fetched and re-confirmed unmoved this round) |
| Port | `ruby` @ `82bf316` (through round 8; round 9 adds the gap-6 decision and the docs recording it) |
| Round | 9 |
| Scan | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` |
| Script hits | self-referential (moves with this file's and `component-parity.md`'s own prose — see round-8 note below, unchanged mechanism) |
| New excuse-shaped sentences this round | **0** |
| **False greens found this round** | **0 new** (round 8's finding 3 — the "13 components" gate mismatch — carries forward, still unresolved on the gate's side; see below) |
| Verdict | **not clean** — not because of the port's own behaviour, but because round 8's finding 3 (a mismatch in an input handed to this audit, not in the port) has still not been answered by whoever computes it |

Scanned `lib/`, `exe/`, `test/`, `.reports/`, `PORTING.md`, `FINDINGS.md`,
`README.md`, `Rakefile`, `flake.nix` and the gemspec for the script's phrase
list, then — the step that matters — checked every factual claim those files
make against a measurement taken this round, not against last round's prose.
Round 7's two findings (`PORTING.md`'s gap-6 miscount, and the `.reports/`
files being a round stale) were both closed by round 7 itself: `PORTING.md`
now opens with `Open gaps | **1**` and keeps gap 6 marked `**OPEN**` rather
than struck through, and all five `.reports/*.md` files carry `Round 7` and
cite live-measured numbers. Both re-checked this round by reading the current
file, not by trusting last round's "closed" label.

---

## 1. CLOSED (round 7, re-verified this round) — `PORTING.md`'s gap counts undercounted by omitting its own admitted half-closure

Round 7 found `PORTING.md:13` and `:71` claiming **0** open gaps while the
gap-6 entry a few lines below its own second header read "half closed" —
a real, deliberate accelerator-less `app.shortcuts` action that upstream does
not have at all. Re-checked this round by reading the current file rather
than trusting last round's "closed" label: `PORTING.md`'s header table now
reads `Open gaps | **1** (component-parity 6 — ...)`, the
`.reports/component-parity.md — 1 open of 9 (gap 6)` subsection header
matches it, and the gap-6 entry itself is written `6. **OPEN** — ...` with
no strikethrough. The code claim underneath is unchanged and still true:
`grep -n "'shortcuts'" lib/main.rb` shows `'shortcuts' => []` still installs
a live action where `src/main.py` installs none. Genuinely closed, not
re-labelled — the header number and the sentence next to it now agree.

## 2. CLOSED (round 7, re-verified this round) — the committed `.reports/*.md` files were a round stale, and read as current

Before this round, `.reports/component-identification.md`,
`component-parity.md` and `test-parity.md` all carried `Round 6` in their
headers and cited **205** `drive_window.rb` checks, a **205**-based coverage
count, and "not clean" verdicts listing round-6 gaps 7/8 (component-parity)
and 14/19/20 (test-parity) as still open. `040f859`
("Close round-6's five open gaps…") landed *after* those files were last
written and closed exactly those gaps in the code — confirmed this round by
reading the current `lib/conversion_row.rb`, `flake.nix`, `Rakefile` and
`test/drive_window.rb` directly rather than trusting either document — but
nobody regenerated the reports to say so. A reader opening
`.reports/component-parity.md` on `ruby`@`040f859` before this round would
have read a verdict the tree had already outgrown.

This is the same failure `.reports/accountability-ensurance.md` round 6
itself flagged in `port-components.tsv`/`port-catalogue.yaml` ("I closed
round 3's gap 9 … and did not re-run the scanner") recurring one directory
over, in the hand-written ledgers rather than the generated TSVs: *treating a
document that should track the tree as though writing `PORTING.md` were
enough.* `PORTING.md` itself even names this precisely, in its own "Open
gaps" header: *"the reports in `.reports/` are round 6's snapshots and have
not been re-run to confirm the closures below"* — the port's own resume
document admitted the staleness and then nobody closed it until this round's
regeneration.

Closed round 7, re-verified this round: every `.reports/*.md` file's header
still names `Round 7`, `Port @ 040f859` and the live-measured numbers below;
nothing in the tree has moved since, so there is nothing to re-stale.

## 3. FALSE GREEN — this round's own commissioning brief quotes a drive-coverage number the port's documentation does not support

The task that opened this round stated the gate as *"228 checks passed, 0
failed, covering 13 components"*. The 228 and the 0 are both confirmed —
`214 + 8 + 6 = 228` across the three drivers, re-run live this round
(`drive_window.rb` 214/214, `drive_translated.rb` 8/8,
`high_contrast_check.rb` 6/6, all `DRIVE OK`). **The "13 components" is not
a number this port's own documentation produces anywhere.**
`.reports/component-identification.md` says *"17 components, matching the
live drive run's coverage count"* for the same drive run, and
`.reports/component-inventory.md`'s upstream census agrees: 17 rows in the
upstream-files-to-port-file mapping. No file in `.reports/`, `PORTING.md` or
the skills' scripts produces 13 for anything — not the file mapping, not the
widget-type count (22 rows), not a driver's step count (97 in
`drive_window.rb` alone). Whoever or whatever computed "13 components" for
this round's brief did so by a method this audit cannot locate and cannot
reconcile against the port's own 17-component census.

This is the thing the task itself warned against treating as settled: *"a
component no check exercises is unverified, not done."* Read the other way,
a *smaller* claimed coverage number than the port's own documentation is not
automatically conservative — it could mean 4 of the 17 named components
really are undriven and the port's "17, matching" claim is the false green
instead. Checked directly this round: every one of the 17 mapped
upstream-file groups in `component-identification.md` has a file that
`test/drive_window.rb` requires (`lib/main.rb`'s own `require_relative`
chain pulls in `about_dialog`, `i18n`, `preferences_dialog`, `settings`,
`shortcuts_dialog` and `window`, which itself requires `conversion_row`, and
`drive_window.rb` separately exercises `converter.rb`'s base-prefix paths at
the window level per `test-parity.md` gap 20's closure) — so the 17 figure,
not the 13, is the one this round's own measurement supports. The 13 in the
brief is unexplained and should be treated as wrong until whoever supplied
it says what it counted.

Rewritten:

> I was handed a gate number — "13 components" — that does not match
> anything the port's own living documentation produces, and I am recording
> that mismatch rather than quietly adopting either number, because the
> alternative is a report that looks reconciled and isn't, which is exactly
> the failure mode this skill exists to catch, including when the unverified
> claim arrives from outside the port rather than from inside it.
> Port: `.reports/component-identification.md` ("17 components"),
> `.reports/component-inventory.md` (17-row upstream census).
> Owed: whoever computes the runtime gate for this fleet should say, in one
> line, what "13 components" counts, so this number can be reconciled
> instead of carried as an unexplained discrepancy every round.

**Round 9 status: still open, on the gate's side, not the port's.** This
round's own commissioning brief repeats the same request verbatim rather than
answering it, which confirms the number is being carried forward by whatever
generates these briefs rather than recomputed each round. Re-checked this
round: `.reports/component-identification.md` and
`.reports/component-inventory.md` still both say 17, nothing in `lib/`,
`exe/`, `test/` or the skills' scripts produces 13 for any count, and no new
candidate explanation turned up. Since the port's side of this cannot move it
further, this audit now also states, for the record, the one count the port
*would* propose if asked: "17" is "distinct upstream-source-file groups ported
to a `lib/*.rb` file", per `component-identification.md`'s own mapping — not a
guess at what "13" meant, which remains unexplained, but a concrete baseline
the gate's owner can confirm or reject the next time this brief is written.

## 4. DECIDED (round 9) — component-parity gap 6 is no longer an open,
   undecided row

Round 9's task brief named this directly: gap 6 (`app.shortcuts` carrying an
accelerator-less action where `src/main.py` creates none) had been
re-confirmed open, by the same evidence, in rounds 6, 7 and 8, without
anyone ever deciding what to do about it — "deliberate and documented" kept
being repeated as though it settled the question, when the gap-6 entries in
both `PORTING.md` and `.reports/component-parity.md` said plainly that it did
not. That is the false-green shape this skill watches for from the opposite
direction: not a claim of progress that didn't happen, but a claim of
rigour ("we correctly keep this open") standing in for the decision the
rigour was supposed to produce.

Round 9 decided it: accepted permanently, under a new named rule
("dead-reference fix") written out in full in
`.reports/component-parity.md`, with the rejected alternative (deleting the
action to reproduce upstream's dead menu item) stated and reasoned about
rather than left implicit. `lib/main.rb`'s and `lib/shortcuts_dialog.rb`'s
own comments, `PORTING.md` item 6, and the parity report now all point at
the same decision and the same reasoning, so a future round re-reads a
closed, reasoned row instead of re-opening an unreasoned one. Verified this
round by reading all four files after editing them, not by trusting the
edit: `grep -n "decided, permanent" lib/main.rb lib/shortcuts_dialog.rb`
and `grep -n "round 9" PORTING.md .reports/component-parity.md` each find
the marker.

## Allowed — a document whose subject is excuses contains the words (re-checked, not re-cited)

- `PORTING.md:39,322-348` — "by design"/"n/a" in the Blockers section and the
  GResource-bundle line. Re-checked against the current tree this round, not
  only against round 6's list: all four blockers still reproduce a real,
  located binding or packaging constraint (`Adwaita::Application` broken in
  the bindings, `Gtk::Accessible#update_property` raising
  `NotImplementedError`, `new_from_appdata` needing a GResource bundle the
  port does not build, Meson/blueprint-compiler having no gem equivalent).
  None of the four hides a feature gap behind the label.
- `.reports/*.md` (this round's five, plus the carried `component-inventory.md`)
  — normal use of "by design"/"n/a" to describe upstream correspondences, per
  the skills' own vocabulary for that case.
- `lib/window.rb:85` — describes upstream's own UX rationale, not a port
  decision. Re-checked by reading the line; unchanged since round 5/6.

## False positives (re-checked)

- `test/high_contrast_check.rb:36` — "an opacity is the one thing a widget
  cannot be asked about from Ruby" states a real binding limitation attached
  to a check that works around it. Unchanged.

## Script scan, re-run live this round

```
$ bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

15 hits this round, over `PORTING.md`, `.reports/component-parity.md`,
`.reports/component-inventory.md` and this file itself — every one
previously seen and re-dispositioned (benign document-about-excuses hits
describing upstream correspondences, plus this file's own quoted excerpts of
the vocabulary it is scanning for, plus the `lib/window.rb:85` false
positive on the `not needed` pattern). The count is self-referential: this
file quotes the scanner's own phrase list to explain dispositions, so
re-running the scan after editing this file's prose moves the number — read
the dispositions below, not the raw count, as the finding. **No new
excuse-shaped sentence describing the port's own behaviour this round.**

## Claims re-verified by measurement this round (not re-cited)

| Claim | How | Result |
|---|---|---|
| `origin/main` unmoved since round 7 | `git fetch origin && git rev-parse origin/main` | still `e96066b1aa0a380a80d63f91bf4d90b70fa51f6d` |
| drive gate: 228 checks, 0 failed, all `DRIVE OK` | `nix develop --command xvfb-run -a rake drive` | confirmed live: `drive_window.rb` 214/214, `drive_translated.rb` 8/8, `high_contrast_check.rb` 6/6 — `214+8+6=228`, matching this round's commissioning brief exactly |
| `rake test` / `test/run_tests.rb` | `nix develop --command xvfb-run -a ruby test/run_tests.rb` | 27 runs, 72 assertions, 0 failures, 0 errors, 0 skips |
| `app.shortcuts` still installs an action upstream never creates (gap 6, now decided) | `grep -n "'shortcuts'" lib/main.rb` | `'shortcuts' => []` present; `src/main.py` has no such action; round 9 accepts this permanently (see finding 4) rather than leaving it open |
| `po/binary.pot` msgid-for-msgid identical to upstream, 32/32 catalogues, 32/32 compiled `.mo` | `git archive origin/main`, `diff` on `msgid` lines, `ls po/*.po locale/*/LC_MESSAGES/*.mo` | identical; 32 and 32 |
| no `TODO`/`FIXME`/"not implemented"/"for now"/"in a future" in `lib/`, `exe/`, `.reports/`, `PORTING.md` | `grep -rniE 'TODO|FIXME|not implemented|for now|in a future' lib/ exe/ .reports/ PORTING.md` | one hit, and it is this phrase list quoted inside this file's own table row, not a stub |
| gate's "13 components" against the port's own census | read `.reports/component-identification.md`, `.reports/component-inventory.md` | both say 17, not 13 — still unreconciled, see finding 3 |

Verdict this round: **not clean**, for one reason only. Finding 4 closes the
one port-side item that was open: gap 6 no longer sits as "deliberate and
documented" doing duty for a decision nobody made — round 9 made it, named
it, and wrote the rejected alternative down. `PORTING.md`'s own header now
reads `Open gaps | **0**`, re-verified by reading the current file rather
than its label. What keeps this round's verdict from being clean outright is
finding 3, carried forward unchanged: the runtime gate this round was handed
still cites "13 components" against a figure the port's own documentation
has never produced (17, everywhere it counts), and that is a property of the
gate's input, not of anything in `lib/`, `exe/` or `test/`. The 228/0/DRIVE-OK
portion of the same gate is independently reproduced and true, same as every
prior round.
