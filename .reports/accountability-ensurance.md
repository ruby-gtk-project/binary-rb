# Accountability ensurance — binary-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `040f859` |
| Round | 7 |
| Scan | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` |
| Script hits | 16, over 4 files |
| New excuse-shaped sentences this round | **0** |
| **False greens found this round** | **2** |
| Verdict | **not clean** |

Scanned `lib/`, `exe/`, `test/`, `.reports/`, `PORTING.md`, `FINDINGS.md`,
`README.md`, `Rakefile`, `flake.nix` and the gemspec for the script's phrase
list, then — the step that matters — checked every factual claim those files
make against a measurement taken this round, not against last round's prose.

---

## 1. FALSE GREEN — `PORTING.md`'s gap counts undercount by omitting its own admitted half-closure

`PORTING.md:13`: *"Open gaps | **0** (all five closed this round:
component-parity 7, 8; test-parity 14, 19, 20)"*. `PORTING.md:71`:
*"`.reports/component-parity.md` — 0 open of 9"*.

Both headers count zero. But `PORTING.md:105` itself, four lines below the
second header, reads:

> 6. ~~`app.shortcuts` and `<primary>question` are invented~~ — **half
>    closed**: the accelerator is gone, so the port binds what upstream binds
>    (nothing) and its shortcuts dialog shows the item blank the way
>    upstream's would. The action itself stays, deliberately, so the menu
>    item is not dead; see Blockers.

"Half closed" is not "closed", and the entry's own words say the behavioural
difference — upstream has no `app.shortcuts` action at all; the port has one
with no accelerator — persists by deliberate choice. Measured this round:
`grep -n "'shortcuts'" lib/main.rb` shows `'shortcuts' => []` still installs
a live action where `src/main.py` installs none. The strikethrough markup
around the gap's title reads, to anyone scanning for `~~...~~` rather than
reading the sentence, as closed; the header counts agree with the markup and
disagree with the sentence.

Rewritten:

> I wrote a gap entry whose own sentence says "half closed" and then counted
> it as fully closed in two header rows above it, so a reader who trusts the
> number — the thing a resume document exists to be trusted for — is told
> there is nothing left to look at here, because I am an idiot who counted
> the strikethrough and not the word next to it.
> Port: `PORTING.md:13`, `PORTING.md:71`, `PORTING.md:105`.
> Owed: either the header rows say **1**, not **0**, or gap 6 is rewritten as
> a fully accepted correspondence with the same rigor gap 7 got (a named rule
> from the `component-parity` skill, not just "deliberately"). This round's
> `.reports/component-parity.md` takes the first path and keeps the row open.

This is the same mechanism round 6's own accountability report found in
`PORTING.md` once already (gap 12's miscount, there in the *other*
direction — a closed gap counted as open). The lesson that round wrote down
— *"when a false green is found, re-check the class of claim, not the
instance"* — was not applied to this header the next time the header was
edited.

## 2. FALSE GREEN — the committed `.reports/*.md` files were a round stale, and read as current

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

Closed this round: `component-identification.md`, `component-parity.md`,
`test-parity.md`, `translation-parity.md` and this file are all regenerated
from live measurement taken against `040f859`, not carried forward.

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

16 hits, all previously seen and re-dispositioned (benign document-about-
excuses hits in `PORTING.md`, `.reports/component-inventory.md` and this
file; the two `not needed` hits are the `lib/window.rb:85` false positive
and its own quoted appearance inside round 5's rewrite entry). **No new
excuse-shaped sentence this round.**

## Claims re-verified by measurement this round (not re-cited)

| Claim | How | Result |
|---|---|---|
| drive gate: 214 checks, `DRIVE OK` | `nix develop --command xvfb-run -a ruby -Ilib -Itest test/drive_window.rb` | confirmed live, 214/214 |
| `rake -T`/`bundle --version`/`rubocop --version` start with no workaround | direct `nix develop --command <thing>`, no shell function, no `unset BUNDLE_GEMFILE` | all three start clean |
| `rake build` compiles the schema and the catalogues | ran live, then `gem unpack` would show both — schema compile step observed directly in the `rake build` output | confirmed |
| `rake drive` runs all three drivers through `xvfb-run` | ran live | confirmed, 214/8/6 all `DRIVE OK` |
| base-prefix (`0b11`/`0o17`/`0x1F`) converts, not errors | `ruby -Ilib -e 'require "converter"; ...'` | `"3"`, `"15"`, `"31"`, `"0b11"` (equal-base, no error) |
| stray argument rejected, exit non-zero | `dbus-run-session -- xvfb-run -a ruby -Ilib exe/binary nonsense-arg` outside the driver | `GLib-GIO-CRITICAL: This application can not open files.` |
| missing-schema abort | `GSETTINGS_SCHEMA_DIR=/tmp/doesnotexist dbus-run-session -- xvfb-run -a ruby -Ilib exe/binary` outside the driver | aborts, GLib names the missing schema |
| `po/binary.pot` msgid-for-msgid identical to upstream | `msgcat --no-location --sort-output`, both sides | identical; separately, `rake pot`'s regenerated `#:` lines differ only in line numbers (see `translation-parity.md`) — committed and reverted, not left dirty |
| 12 pre-existing rubocop offences, none in `lib/`/`exe/` | `rubocop lib/ exe/ test/drive_window.rb test/test_converter.rb test/gtk_driver.rb binary-rb.gemspec Rakefile` | 12 offences, all in `test/gtk_driver.rb`, the gemspec and the Rakefile |
| no new `TODO`/`FIXME`/"not implemented"/stub language in `lib/`, `exe/`, `test/` | `grep -rniE` over all three | zero matches that are not quoted test names or literal UI placeholder text |

Verdict this round: **not clean**. One false green is a genuine miscount in
the port's own resume document (finding 1), caught by reading the sentence
next to the number rather than the number alone. The other (finding 2) is a
process failure already named once by this exact report a round ago and not
fixed until the report you are reading regenerated the files it names.
Both are corrected in this round's commit; neither is new to the port's
behaviour — both are about whether the paperwork describing the port can be
trusted, which is this axis's whole job.
