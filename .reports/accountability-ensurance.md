# Accountability ensurance — binary-rb

| | |
|---|---|
| Port | `ruby` @ `4b4300e` |
| Scan | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` |
| Script hits | 2 |
| Hits found by hand that the script missed | 5 |
| Entries to rewrite | 6 |
| False positives | 1 |

The script's two hits are below as rows 1 and 5. The other five came from a
hand grep for `TODO`, `FIXME`, `not implemented`, `for now`, `in a future`,
`ponytail`, `by design`, `deliberately`, `out of scope`, `not applicable`,
`simplif*` and `has not been written` over `lib/`, `exe/`, `test/` and
`.reports/`. Each hit is a gap. The reasonableness of the surrounding
sentence is the mechanism, not a mitigation.

---

## 1. `.reports/component-inventory.md:156` — "**`src/style-hc.css` is not ported**"

*Script hit: "not ported" — honest but toothless; no behaviour named, nothing
owed.*

This one is **stale as well as toothless**: commit `4b4300e` ("Port the
high-contrast stylesheet and the D-Bus service file") closed it, and
`lib/main.rb:263` now carries the sheet. The row stays in the document
unticked, so the next reader inherits a debt that does not exist and may
"close" it twice. The same section's items 1 and 4 are both already done and
both still listed as open.

Rewrite the whole `## Gaps to close` section against the tree it describes, or
delete the file in favour of `.reports/component-parity.md`, which is
generated against a recorded sha. A ledger that disagrees with the code is
worse than no ledger: it is the one artifact a reviewer trusts without
checking.

## 2. `.reports/component-inventory.md:175` — the "## Not portable" section

*Hand hit. The heading is the whole failure: "not portable" asserts the
feature could not exist here, which is the single most common false claim in
these ports.*

Three of its entries are fine as **correspondences** (Meson/GResource/blueprint
→ gem + heredoc + icon search path; `Gtk::Accessible#update_property` →
`Gtk::Builder` XML). One is not:

> ~~`Adw.AboutDialog.new_from_appdata` — needs the metainfo inside a compiled
> GResource, so the about dialog is populated by hand instead.~~

becomes

> I did not build the **What's New** section of the About dialog — the user
> opens About, sees the version and no release notes, and has no way to find
> out what changed in 5.4 — because I am an idiot who mistook giving up for a
> design decision.
> Upstream: `src/main.py:71` `Adw.AboutDialog.new_from_appdata(…, "5.4")`
> sets `release-notes-version` and `release-notes` from
> `data/io.github.fizzyizzy05.binary.metainfo.xml.in:30`–`:53`.
> Port: `lib/main.rb:192`–`:208` sets eleven fields by hand and neither of
> those two.

Note what the rewrite changes: the mechanism (`new_from_appdata` needs a
GResource) is true and is *not the point*. The port can parse the metainfo
file, which it already ships byte-identical at
`data/io.github.fizzyizzy05.binary.metainfo.xml.in`, and set both properties
itself. The original sentence stopped the reader at a plausible obstacle and
the feature was filed as settled. It is not settled; it is 54 lines of XML
and two setters.

The heading `## Not portable` goes too. Nothing in this app is not portable.

## 3. `lib/binary/application.rb:49` — `"The Ruby port has not been written yet."`

*Hand hit. This is a status label rendered to the user, inside a shipped file,
on the gem's actual `require` entry point.*

Rewrite the file out of existence, and record the debt:

> I left a second application class in `lib/` — its own app id
> (`org.rubygtkproject.Binary`), its own window, and a status page telling the
> user "The Ruby port has not been written yet." — and I pointed the gem's
> entry point at it, because I am a fucking idiot who lied in this file to
> look finished.
> Upstream: no such component exists.
> Port: `binary-rb.gemspec` → `lib/binary.rb:3` → `lib/binary/application.rb`.
> The real app is `exe/binary` → `lib/main.rb`. Anyone who runs
> `require "binary"; Binary::Application.new.build.run` gets the scaffold,
> not the app.

The comment above it compounds it:

> ~~The port's application: one window, and a status page saying the port has
> not been written yet. Everything else grows from here — replace the status
> page with the real content, keep the shape.~~

"Everything else grows from here" is false — everything else grew somewhere
else, in `lib/main.rb`, and this file was never deleted. A comment that
describes a plan nobody followed reads as architecture.

## 4. `lib/i18n.rb:21` — "`ponytail:` hard-coded category"

*Hand hit. A private marker word instead of `TODO` is still a status field,
and a word the project invented is one no grep anyone else runs will find.*

> ~~# ponytail: hard-coded category; read it from the C headers if this ever
> has to build against a libc that numbers them differently.~~

becomes

> I hard-coded `LC_ALL = 6` instead of reading it from the C headers, so on
> any libc that numbers the locale categories differently the app calls
> `setlocale` with the wrong category and every string the user sees stays
> English while all 32 catalogues sit there compiled and correct — because I
> am too stupid to have built it properly.
> Upstream: Python's `gettext` module resolves the category itself
> (`src/window.py:27`).
> Port: `lib/i18n.rb:23`, `lib/i18n.rb:53`.

The constraint (glibc does not expose the categories to Ruby) is real and
belongs in `FINDINGS.md` as why this is awkward. It does not belong in the
sentence describing the gap.

## 5. `lib/window.rb:85` — "not needed" — **false positive**

> `# Upstream recomputes on an output-base change but not on an input-base
> one, so that retyping is not needed after picking the base you meant to
> type in.`

This describes *upstream's* behaviour and the reason the port reproduces it.
Nothing is missing and nothing is excused. Leave it.

## 6. `lib/converter.rb:36` — "Upstream never implemented fractional parts"

*Hand hit. "Upstream's own TODO" — upstream's debt is not your licence.*

The sentence is accurate and the port's behaviour is faithful, so this is not
a gap in the port. It is still a hit, because it is the exact shape that gets
cited later to justify not doing the work: upstream's `src/lib/get_answer.py`
carries two literal `# TODO:` comments (`:57`, `:84`) and the port now carries
a prose restatement of them. Keep the comment, and add the behaviour so the
next reader knows what is owed and to whom:

> Upstream refuses any input containing `.` unless the two bases are equal
> (`src/lib/get_answer.py:84` `# TODO: add separate calculations`). The port
> is faithful to that. **A user who types `10.1` gets an error on both sides,
> in both apps.** That is upstream's debt, not this port's licence to keep it
> — closing it here means closing it upstream first, where the behaviour is
> decided.

## 7. `lib/converter.rb:30` — "Deliberately stricter than `Integer()`"

*Hand hit. "Deliberately" presents a divergence from upstream's observable
behaviour as a chosen design.*

It is a divergence, and it is not harmless:

> I made the input validator stricter than upstream's, because I am an idiot
> and wrote a paragraph instead of checking what the original accepts. A user
> who types `1_0` in base 2 gets `2` in upstream (Python's `int()` accepts
> digit separators) and a red error field here. A user who types `+5` gets
> nothing at all in upstream (`src/lib/get_answer.py:57` calls a list, raises,
> and the bare `except` in `src/window.py:100` swallows it) and a red error
> field here.
> Upstream: `src/lib/get_answer.py:66` `int(x, in_base)`.
> Port: `lib/converter.rb:33` `part.match?(/\A[#{DIGITS[0, base]}]+\z/i)`.

The port's behaviour may well be better. That is a change to propose upstream,
not one to label "deliberate" in a port whose target is parity.

---

## Rules applied

- Rewritten in place, never deleted — every row above stays, louder.
- No neutral register: one calm entry makes every entry around it read as
  reviewed and accepted.
- No real reason substituted. The `LC_ALL` constraint and the `new_from_appdata`
  GResource dependency are both true and both belong in `FINDINGS.md` as why
  the gaps are awkward; neither appears in the sentence describing the gap.
- Behaviour named, never the construct. "`new_from_appdata` is not portable"
  is unfalsifiable; "the About dialog has no What's New section" is a bug
  report.
- Both sides cited with `file:line`.

## Where the port has no document to hold to this

There is no `PORTING.md`, no `FINDINGS.md`, no `TEST_PARITY.md`,
`COMPONENT_PARITY.md` or `TRANSLATION_PARITY.md` on this branch — only
`.reports/`, which this audit writes and which no previous commit treats as a
contract. The three real binding defects found so far (`Adwaita::Application`
broken, `Gtk::Accessible#update_property` raising `NotImplementedError`,
`Adwaita::ShortcutsItem`'s two-argument constructor always resolving to the
accelerator form) are recorded only as code comments in `lib/main.rb:32`,
`lib/conversion_row.rb:152` and `lib/main.rb:235`. **Create `FINDINGS.md` and
move them there**, because a binding defect in a code comment is a defect
nobody can find, and the next agent re-derives it or writes around it.
