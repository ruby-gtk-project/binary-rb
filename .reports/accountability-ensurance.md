# Accountability ensurance — binary-rb

| | |
|---|---|
| Port | `ruby` @ `eff4fa3` |
| Scan | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` |
| Script hits | 12, over 3 files |
| Hits the script could not find, found by hand | 6 |
| Entries to rewrite | 7 |
| Allowed (a document *about* excuses) | 9 |
| False positives | 2 |
| Round | 3 |

The script's hits are listed first. The hand hits came from reading `README.md`,
`AGENTS.md`, `FINDINGS.md`, `lib/`, `exe/`, `test/`, `Rakefile`,
`binary-rb.gemspec` and `.reports/` for `TODO`, `FIXME`, `not implemented`,
`for now`, `in a future`, `by design`, `deliberately`, `out of scope`,
`not applicable`, `simplif*`, `stub`, `placeholder` and `unsupported`, and from
checking every factual claim those files make against the tree.

**Each hit is a gap. The reasonableness of the surrounding sentence is the
mechanism, not a mitigation.** Six of the seven rewrites below are not
excuses in the classic shape at all — they are *false claims*: sentences that
describe a state the tree is not in. That is the same failure one step worse,
because an excuse at least admits something is missing.

---

## 1. `.reports/component-inventory.md:189-196` — "Nothing is missing from the user's side; the file layout is wrong."

*Hand hit. The calmest sentence in the port, and the reason this entry is
first: it is a live, open gap written in the neutral register, which the next
reader will file as reviewed and accepted.*

Rewritten:

> I did not give the About dialog, the preferences dialog or the shortcuts
> dialog a file of their own, so the three upstream units a reader goes looking
> for are buried in the middle of a 340-line application singleton and the next
> person to touch one has to read all of it — because I am an idiot who decided
> a house rule I found inconvenient was a matter of taste.
> Upstream: `src/main.py:70-78` (About), `src/preferences.py` +
> `src/preferences.blp` (preferences), `src/shortcuts-dialog.blp` (shortcuts) —
> three separate files, two of them whole units with their own template root.
> Port: `lib/main.rb:248-314`, all three. The pilot port has
> `gnome-contacts-rb/lib/preferences_dialog.rb` and
> `gnome-contacts-rb/lib/shortcuts_dialog.rb`, so the shape exists and I did
> not follow it. Owed: `lib/about_dialog.rb`,
> `lib/preferences_dialog.rb`, `lib/shortcuts_dialog.rb`.

Note what the original sentence does: "Nothing is missing from the user's side"
invites the reader to agree, and once they agree the row is closed. It also
happens to be wrong — two of the gaps in
`.reports/component-parity.md` (1 and 2, the memoized dialogs) are *in those
very methods*, and a reader who accepted "nothing is missing from the user's
side" would never have looked.

---

## 2. `AGENTS.md:3` — "This branch is an empty `ruby` orphan branch."

*Hand hit. Flatly false, and it is the first sentence the next agent reads.*

Rewritten:

> I left the agent instructions saying this branch is empty, so the next agent
> opens the file, believes there is nothing here, and starts the port again
> over the top of seven finished files — because I am a fucking idiot who wrote
> a sentence once and never read it again.
> Upstream: n/a — this is the port's own document.
> Port: `AGENTS.md:3`. The branch carries `lib/binary.rb`, `lib/main.rb`,
> `lib/window.rb`, `lib/conversion_row.rb`, `lib/converter.rb`, `lib/i18n.rb`,
> `lib/settings.rb`, `exe/binary`, a 32-language `po/`, a test suite of 24
> minitest assertions and 62 driven checks, and 23 screenshots. Owed: the
> sentence replaced with what the branch actually holds, plus the cursor.

---

## 3. `test/gtk_driver.rb:24-25` — "Run it with no display server at all … No Xvfb needed."

*Hand hit. False, known to be false, and the correction was filed somewhere
else instead of fixing the sentence.*

Rewritten:

> I shipped a driver whose own documentation tells you it needs no display, so
> anyone who follows it gets `Gtk::InitError: failed to initialize GTK` and no
> idea why — because I am an idiot who wrote down a finding instead of
> correcting the lie it was a finding about.
> Upstream: n/a — this is the port's own harness.
> Port: `test/gtk_driver.rb:24-25`. `FINDINGS.md` section 11 already says the
> claim is wrong, verified again this round: `require 'adwaita'` raises with
> `DISPLAY` and `WAYLAND_DISPLAY` unset, before any window is made. Owed: the
> comment corrected, and `xvfb-run` added to the devShell so the statement can
> be made true instead of deleted.

---

## 4. `README.md:15` and `lib/settings.rb:10` — `ruby bin/binary`

*Hand hit. The one documented way to start the app does not exist.*

Rewritten:

> I documented a command that cannot run, so the only instruction the README
> gives for launching the app is `ruby bin/binary` and there is no
> `bin/binary` — because I am an idiot who renamed a file and grepped nothing.
> Upstream: `src/binary.in` → `configure_file` → an installed `binary` on
> `$PATH`; `README.md` upstream documents `flatpak run`.
> Port: `README.md:15` says `ruby bin/binary`; `bin/` holds only `setup` and
> `turbo_tests2`, and the executable is `exe/binary`. `lib/settings.rb:10`
> repeats the wrong path in a comment explaining where
> `GSETTINGS_SCHEMA_DIR` gets set. Owed: both references pointed at
> `exe/binary`.

---

## 5. `.reports/translation-parity.md` (round 2 header) — "`po/` is byte-identical to upstream, file for file"

*Hand hit. A green claim that stopped a diff from being run, and behind that
diff sat a real loss.*

Rewritten:

> I wrote down that the catalogues were byte-identical to upstream's and then
> let `rake pot` rewrite all 33 of them without re-checking, so the one comment
> that tells 32 languages' translators what to put in `translator-credits` is
> gone and the ledger says everything is fine — because I am an idiot who
> treated my own earlier sentence as evidence.
> Upstream: `src/main.py:79`, `#. Translators: Replace "translator-credits"
> with your names, one name per line`, extracted into all 32 `.po` files.
> Port: zero copies of it, because `lib/main.rb:263` reads `# Translators put
> their own names here…` and `Rakefile:194`'s `--add-comments=Translators:`
> needs the tag verbatim. Tracked as gap 2 in
> `.reports/translation-parity.md`. Owed: the upstream comment transcribed and
> `rake pot` re-run.

---

## 6. `binary-rb.gemspec:18` + `:64-69` — a GPL-3 declaration with no GPL-3

*Hand hit. Not worded as an excuse; worded as a fact that is not one.*

Rewritten:

> I shipped a GPL-3 derivative of someone else's GPL-3 application with no copy
> of the licence anywhere in it, and declared the licence in the gemspec
> anyway, so the gem asserts terms it does not distribute — because I am an
> idiot who filled in a metadata field and called it compliance.
> Upstream: `COPYING`, the full GPL-3 text, at the repository root.
> Port: no `COPYING`, no `LICENSE.md`. `binary-rb.gemspec:18` declares
> `["GPL-3.0-or-later"]` and `:64-69` lists `LICENSE.md` behind a
> `.select { File.exist? }` that drops it in silence, so nothing even warns.
> Owed: upstream's `COPYING` copied in, under that name or as `LICENSE.md`.

---

## 7. `binary-rb.gemspec:71-82` — 882 translated strings that never ship

*Hand hit. The exact failure the translation ledger exists to catch, hiding
behind that ledger's own pass.*

Rewritten:

> I did not package the compiled catalogues, so a user who installs this gem
> gets an app that is English in all 32 languages while my own report says
> "32 → 32" at the top — because I am an idiot who counted a directory in the
> checkout instead of the files that ship.
> Upstream: `po/meson.build` → `i18n.gettext('binary')` installs one `.mo` per
> language into `$localedir`; `src/binary.in:33-34` binds the domain to it.
> Port: `spec.files` globs `lib`, `exe`, `data/**/*` and `po/**/*` and never
> `locale/**/*`; `lib/main.rb:46-49` then looks in `../locale` (absent in an
> installed gem) and `/usr/share/locale` (where no `binary.mo` is). Tracked as
> gap 1 in `.reports/translation-parity.md`. Owed: `locale/**/*` in
> `spec.files`, and a check that fails if a shipped `.mo` is missing.

---

## Allowed, not rewritten

- **`.reports/accountability-ensurance.md`, 9 hits** (lines 14, 21, 23, 57, 125, 128, 136 and this round's equivalents). This is the document *about* excuses; it quotes the constructions in order to name them. The skill exempts exactly this case.
- **`.reports/component-inventory.md:201`** — "an idiot who mistook giving up for a design decision". The phrase "design decision" is inside a first-person admission that denies it was one. Correctly written.

## False positives, read and left

- **`lib/window.rb:85`** — "so that retyping is not needed after picking the base you meant to type in." Describes **upstream's** behaviour (`src/window.py:95`'s commented-out `self.output_handler()` versus `:105`'s live call) and explains why the port's `#change_input_base` and `#change_output_base` differ from each other. It excuses nothing; the behaviour is ported.
- **`lib/converter.rb:56-61`** — quotes upstream's own `# TODO: add separate calculations` and states that fractional conversion across unequal bases errors in both apps. This is the one shape the skill's "upstream's debt is not your licence" pattern cannot distinguish from a real excuse, and here the sentence already says it: *"That is upstream's debt, not this port's licence to keep it — closing it here means closing it upstream first, where the behaviour is decided."* Reproducing an upstream bug **is** parity; the port's target is upstream, and a port that fixed it would be the divergence. Left as written.

## Where a binding limitation is being asked to do a gap's job

`FINDINGS.md` section 1 — "`Adwaita::Application` is unusable in the bindings,
so the port uses `Gtk::Application`" — is in the right file and is the right
shape: it records why something is hard. But it is also the **only** record of
the substitution, and the substitution carries a behaviour change that appears
in no gap row anywhere:

> I swapped `Gio.ApplicationFlags.DEFAULT_FLAGS` for `:handles_command_line`
> while working around the bindings, so `binary 42` now opens a window where
> upstream refuses the argument, and I wrote the workaround down and not its
> cost — because I am an idiot who recorded the obstacle and skipped the
> consequence.
> Upstream: `src/main.py:34` `flags=Gio.ApplicationFlags.DEFAULT_FLAGS`;
> GApplication rejects a non-option argument.
> Port: `lib/main.rb:219` `Gtk::Application.new(APP_ID, :handles_command_line)`
> and `#handle_command_line` (`:116-122`), which scans for `--new-window`/`-w`
> and otherwise activates. Tracked as gap 4 in
> `.reports/component-parity.md`. Owed: either upstream's rejection
> reproduced, or the divergence written down where someone will meet it.

Three further gaps found this round were not being excused by anything — they
were simply never looked at, which is the failure mode one rung below this
skill: `exe/binary` dropping GLib's exit status, the two memoized dialogs, and
nothing installing the `.desktop`/`.service`/metainfo files. All four live in
`.reports/component-parity.md` as gaps 1, 2, 5 and 6.

## Verdict

**7 entries rewritten, 1 binding-limitation record carrying a gap it should
not, 2 false positives, 9 allowed.** Not clean.
