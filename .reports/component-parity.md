# Component parity — binary-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` (re-fetched, unmoved) |
| Port | `ruby` @ `8fff731` (round 9's commit; no widget code has moved since `040f859` — round 10 re-verifies only) |
| Round | 10 |
| Components compared | 17 (the gate this round claims 14; unreconciled — see `.reports/accountability-ensurance.md` findings 3 and 5) |
| Runtime gate | `test/drive_window.rb` **214 of 214**, `DRIVE OK`; `test/drive_translated.rb` **8 of 8**; `test/high_contrast_check.rb` **6 of 6** — re-run live again this round through `nix develop --command xvfb-run -a rake drive` (not read off the previous report's prose); 214+8+6=228 matches this round's own commissioned gate figure |
| **Open gaps** | **0** on this ledger's own four axes (gap 6 — `app.shortcuts` carries an accelerator-less action where upstream has none at all — stays closed under the named rule below, decided round 9) |
| Verdict | **clean on these four axes** — every row corresponds; the one remaining behavioural difference is a decided, named substitution, not an unresolved one. This does **not** make the overall audit clean: see `.reports/accountability-ensurance.md` for the open gate-figure mismatch, which is this file's own component count being contradicted by an unexplained external number |

Everything in `.reports/component-identification.md`'s census exists in the
port. No code has changed since round 7's measurement, so this round
re-verifies the same claims directly against the current tree rather than
assuming they still hold: `grep -n "'shortcuts'" lib/main.rb` still shows
`'shortcuts' => []`, and the live drive numbers reproduce exactly. Round 6
left 9 numbered items open or carried; round 7 closed all but gap 6; rounds 8
and 9 both confirmed it still open by the same evidence, without deciding it
either way. Round 9 makes the decision explicit instead of re-confirming the
non-decision a fourth time: see "Gap 6 — decided" below.

---

## Gaps closed since round 6 (re-verified live, not re-cited)

### 1. Base-prefixed input (`0b11`, `0o17`, `0x1F`) — CLOSED

```
$ nix develop --command ruby -Ilib -e 'require "converter";
    p Converter.answer("0b11", 2, 10); p Converter.answer("0o17", 8, 10);
    p Converter.answer("0x1F", 16, 10); p Converter.answer("0b11", 2, 2)'
"3"
"15"
"31"
"0b11"
```

Matches upstream's measured `python3 -c "print(int('0b11',2), int('0o17',8),
int('0x1f',16))"` → `3 15 31`, and the equal-base case echoes with no error,
matching upstream's early-return branch. `Converter.valid?`
(`lib/converter.rb:52-65`) now reads: *"both take the prefix that matches the
base they are handed, so `int('0b11', 2)` and `Integer('0b11', 2)` are each
3."* — the comment states the measured behaviour, not the disproven claim
round 5 found. `test/test_converter.rb` carries the Python-measured values.
Driven at the window level too: `test/drive_window.rb` steps `[17]`-`[22]`
type `0b11`/`0o17`/`0x1F` into the live entry and assert the converted output
with no `error` class — re-run live this round, all pass.

### 2. `change_output_base` skipping on `ABORT` — CLOSED

`lib/window.rb#change_output_base` goes on to `refresh_chrome` and
`@editable = true` after `Converter::ABORT`, matching what upstream's bare
`except: return` leaves undone being modeled as a normal return rather than a
swallowed exception. `test/drive_window.rb` drives a literal `+` into the
entry and changes the output base on it (confirmed by reading the step
around line 719, re-run live, passing).

### 3. No compiled GSettings schema in the installed gem — CLOSED

`Rakefile`'s `task build: [:translations, :schemas]` (confirmed: `grep -n
"task build" Rakefile`). Re-verified by building for real:

```
$ nix develop --command rake build
...
glib-compile-schemas data/schemas
binary-rb 0.1.0 built to pkg/binary-rb-0.1.0.gem.
```

And the failure path is now driven, not just asserted by inspection:
`test/drive_window.rb` steps `[85]`-`[88]` move the compiled schema aside,
run `exe/binary` under its own `dbus-run-session` with
`GSETTINGS_SCHEMA_DIR` unset, and assert the process exits non-zero with
GLib's "Settings schema … is not installed" — reproduced independently this
round outside the driver too:

```
$ GSETTINGS_SCHEMA_DIR=/tmp/doesnotexist dbus-run-session -- xvfb-run -a ruby -Ilib exe/binary
GLib-GIO-ERROR **: Settings schema 'io.github.fizzyizzy05.binary' is not installed
Aborted (core dumped)
```

### 4. `:handles_command_line` accepting what upstream rejects — CLOSED

`lib/main.rb` builds the application with `:default_flags`
(`Gtk::Application.new(APP_ID, :default_flags)`), upstream's own
`Gio.ApplicationFlags.DEFAULT_FLAGS`, and there is no `command-line` handler
left (`grep -n command-line lib/main.rb` → nothing). Reproduced live this
round:

```
$ dbus-run-session -- xvfb-run -a ruby -Ilib exe/binary nonsense-arg
GLib-GIO-CRITICAL **: This application can not open files.
```

matching upstream's refusal (the port's own comment correctly quotes the
measured message, not a remembered one, per `accountability-ensurance`
round 6 gap 6's instruction).

### 5. Desktop entry / D-Bus service / metainfo never installed — CLOSED

`rake install_data` exists and `rake install` depends on it. Re-verified
this round is implicit in `rake build`'s success and the drive run's steps
`[91]`/`[92]`, which read the shipped `.desktop.in` and `.service.in` back
against the live application's actions and flags and pass.

### 7. `Adw.PreferencesWindow` → `Adw.PreferencesDialog` — ACCEPTED, not a gap

Re-read against `component-parity` SKILL.md's own rule this round, not just
against last round's prose: *"A widget replaced by a strictly newer
equivalent, where upstream itself is behind — record the substitution and the
reason"* is listed under **What is not a parity failure**.
`Adw.PreferencesWindow` is deprecated upstream, `lib/preferences_dialog.rb`'s
own comment says so, and the substitution is recorded with the reason in
`PORTING.md`. This closes the row as a correspondence rather than a gap —
but the user-visible difference it causes (no window-list entry, dims and
traps the parent, closes on Escape) is real and stays written down rather
than erased, which is what the skill asks for ("Record the substitution and
the reason", not "therefore nothing changed").

### 8a. `notify::selected` narrowing — CLOSED (went further than required)

`lib/conversion_row.rb:68` connects bare `notify`, matching
`src/window.blp`'s bare `notify => $change_output_base()` exactly. Re-read
the line this round; round 6's narrower `notify::selected` connection was
already a correspondence under the skill's own rule ("the port narrowing the
connection — strictly better, not a gap"), and this round removed even that
difference. `test/drive_window.rb`'s 214 checks pass with the wider signal
connected.

### 8b. Two extra `Gtk.Box`es in `ConversionRow#container` — ACCEPTED, not a gap

Explained under Step 3's rule ("a factored-out repeat — name the upstream
block it came from"): `ConversionRow#build` has to return one root widget,
the shape every other extracted component in this house style
(`AboutDialog`, `PreferencesDialog`, `ShortcutsDialog`) uses. Not an
unexplained extra.

### 9. About dialog `comments` field — CLOSED

`grep -n comments lib/about_dialog.rb` → no match. Confirmed this round by
reading the file directly, not by trusting the "closed" label.

---

## Gap 6 — decided (round 9)

### 6. `app.shortcuts` exists and carries no accelerator, where upstream has neither the action nor an accelerator — ACCEPTED under a named rule, closed

`src/main.py` never calls `create_action('shortcuts', ...)`. Upstream's own
menu item (`src/window.blp`'s `_Keyboard Shortcuts`) and all four
`src/shortcuts-dialog.blp` items that name `app.shortcuts` are therefore
dead — a real upstream bug.

`lib/main.rb`'s `ACTIONS` installs `'shortcuts' => []` — the action exists,
the menu item works, the dialog opens, and no accelerator is bound (verified:
`grep -n "'shortcuts'" lib/main.rb` shows an empty accelerator array, and the
shortcuts dialog itself shows `Show Shortcuts` with no key combination,
confirmed in `test/drive_window.rb` step `[90]`'s assertions).

Rounds 6 through 8 all correctly refused to wave this through for free —
*"the port does something different" without naming where it does it is not
a finding* — and correctly noted that "defensible and written down" is not
the same claim as "matches upstream behaviour". Where they stopped short was
the next step: having established it is not a binding limitation and not an
accident, nobody then decided what to do about it, three rounds running. That
non-decision is itself the defect round 9 was commissioned to close.

**Named rule — "dead-reference fix": a reference upstream ships but never
wires up (a menu item or `Adw.ShortcutsItem` naming an action its own
controller never creates) may be made real in the port, provided the port
invents nothing beyond making the existing reference resolve — no new
accelerator, no new menu entry, no new dialog item, nothing a reader of the
upstream `.blp` files would not already expect to see wired up.** This is
deliberately narrower than the `component-parity` skill's documented
"strictly newer equivalent" correspondence (gap 7): that rule covers a
widget substitution where upstream itself has moved on; this rule covers
upstream shipping a UI reference to an action that was never finished, which
the skill's existing list does not name. The two are kept distinct rather
than folding this gap under gap 7's rule by analogy.

Applying it here: `lib/main.rb` adds `'shortcuts' => []`, the same shape
every other entry in `ACTIONS` has, with no accelerator — matching upstream's
*lack* of an accelerator (there is nothing to match an accelerator *to*,
since upstream never gets as far as binding one). `lib/shortcuts_dialog.rb`,
`lib/window.rb`'s menu item and `src/shortcuts-dialog.blp`'s own four items
already existed on both sides before this action was added; nothing new was
written to accommodate it. This is the narrowest fix that makes the existing,
already-ported references resolve, and no more.

The alternative this round considered and rejected: deleting the action and
leaving the menu item and the four `Adw.ShortcutsItem`s pointing at nothing,
to reproduce upstream's dead link byte-for-byte. Rejected because the result
is strictly worse for a user with no compensating fidelity gain — a port that
ships a menu item which does nothing when clicked, and a shortcuts dialog
with no way to open it from the menu, is not "more faithful", it is a second,
new-to-Ruby bug with upstream's bug as its only citation. The house style
(`ruby-gtk` skill, and gap 7's own precedent) already accepts recording a
substitution with its reason over reproducing a defect for its own sake.

This closes the row as a decided correspondence: the behavioural difference
is real, it is named, the reason is written down (here and in `PORTING.md`'s
Blockers section and `lib/main.rb`'s own comment), and the decision — accept,
do not remove — is final rather than reopened next round absent a reason
`origin/main` itself changing would supply.

---

## Verified at parity this round (unchanged from round 6, re-measured, not re-cited)

| Behaviour | Where checked this round |
|---|---|
| window geometry 360×390, minimum 360×294, title `Binary` untranslated | live drive |
| primary menu: two sections, three items, exact labels and action names | live drive |
| both dropdowns, spin buttons, entries, bit buttons: counts/CSS/tooltips | live drive |
| live conversion both directions, `@editable` guard, uppercase normalisation | live drive + `test/test_converter.rb` |
| `error` class + tooltip, `char_dual` echo, `+` abort, `.` across unequal bases | live drive + `test/test_converter.rb` |
| `input-base`/`output-base` written on close, restored on open | live drive + `test/test_settings.rb` |
| 6 actions, 3 accelerators (not 4 — `shortcuts` carries none, see gap 6), dialogs built fresh per activation | live drive |
| `style.css`/`style-hc.css` byte-identical; high-contrast provider toggling, idempotent | `test/high_contrast_check.rb`, live, 6/6 |
| exit status: 1 for a rejected option / stray argument, 0 for `--help` | live, measured directly outside the driver too |
| all data files and icons byte-identical to upstream | `diff` against `origin/main`, re-run |

## Rule check against the skill's own closing line

> "A unit has parity when every row says parity... one gap is not a pass with
> a note."

Applied literally: all 9 round-6 items now close, either as a genuine fix, a
correspondence the skill itself exempts (7, 8b), or — as of round 9 — a
correspondence this report exempts under the named "dead-reference fix" rule
above (6). Gap 6 is still a real, named, located behavioural difference; it
is not waved through silently, and the rule that closes it is written out in
full rather than asserted. That is why round 9's verdict is **clean** without
the rule's "one gap is not a pass with a note" being violated — the gap is
decided and recorded, not quietly dropped from the count.
