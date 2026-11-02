# Translation parity — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `4b4300e` |
| Domain | `binary` (upstream's, confirmed from `data/…gschema.xml` `gettext-domain="binary"`, `<translation type="gettext">binary</translation>` in the metainfo, and `po/binary.pot`) |
| Upstream messages | 30 |
| Ported | **30** (round 2: `bits` added, and the nine keys that only the census could see are now literals at their call sites) |
| Gaps | **0** |
| Extra (untranslated) | 1 (test-only) |
| Upstream occurrences | 41 across 30 messages (6 reused) |
| Port occurrences | 37 |
| Upstream languages | 32 `.po` files, 882 translated, 78 untranslated, 0 fuzzy |
| Languages shipped by the port | 32 — `po/` is byte-identical to upstream, file for file, including `LINGUAS` and `binary.pot` |
| `domain_matches` | true |
| Build command | `rake translations` → `locale/<lang>/LC_MESSAGES/binary.mo` |
| Checks run | round 2, inside `nix develop` under `xvfb-run -a`: `rake translations` (32 `.mo` files via `msgfmt`), `rake pot` (`xgettext` + `msgmerge` over all 32 `.po`), `rake test` (**24 runs, 62 assertions, 0 failures**) and `rake drive` (`drive_window.rb` **54/54**, `drive_translated.rb` **8/8**, including the eight German-locale on-screen assertions) |
| `rake pot` outcome | `po/binary.pot` regenerated: its `(msgctxt, msgid)` set is **identical** to upstream's pot, and **no `.po` gained a `#~` block** — the obsolete-entry count is unchanged in all 32 files |

Generated documents: `.reports/translation-parity.yaml`,
`.reports/upstream-catalogue.yaml`, `.reports/port-catalogue.yaml`.

`summary.parity` in the generated comparison is **false**.

## Hand-censused rows

`totals.unresolved` is **4** for the port, so the ledger could not be written
from the census alone. Five further rows the census reported as gaps are
scanner misses, not gaps — resolved by reading the call sites:

| Site | Why the census could not read it | Keys it actually produces |
|---|---|---|
| `lib/main.rb:230` `c_(SHORTCUT_CONTEXT, title)` over `lib/main.rb:32` `SHORTCUTS` | both arguments are constants | `shortcut window`␄`New Window`, `Close Window`, `Show Shortcuts`, `Quit` |
| `lib/main.rb:227` `c_(SHORTCUT_CONTEXT, 'General')` | first argument is a constant | `shortcut window`␄`General` |
| `lib/conversion_row.rb:109` `n_(*@bit_plural, digit_count)` over `lib/window.rb:313`, `:322` | splatted instance variable | `%(in_count)d bit`, `%(out_count)d bit` |
| `lib/main.rb:197` `_(SUMMARY)` over `lib/main.rb:18` | constant, assembled from two adjacent literals | `A small and simple app used to convert between different hexadecimal and binary numbers` — verified byte-identical to `po/binary.pot` |

All of these produce upstream's exact keys at runtime, so they are `ported`.
**They are also the subject of the worst finding in this ledger — see
"`rake pot` destroys 288 translations" below.** The census defect (a `c_` whose
context is a constant produces no row at all, not even an `!unresolved` one)
should be reported back to the `translation-parity` skill.

## src/window.py + src/window.blp → lib/window.rb + lib/conversion_row.rb (16 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 1 | — | `Main Menu` | single | 1 → 1 | `lib/window.rb:250` | ported | |
| 2 | — | `New Window` | single | 1 → 1 | `lib/window.rb:263` | ported | |
| 3 | — | `_Keyboard Shortcuts` | single | 1 → 1 | `lib/window.rb:269` | ported | |
| 4 | — | `_About Binary` | single | 1 → 1 | `lib/window.rb:270` | ported | |
| 5 | — | `Input Base` | single | 1 → 1 | `lib/window.rb:312` | ported | |
| 6 | — | `Output Base` | single | 1 → 1 | `lib/window.rb:321` | ported | |
| 7 | — | `Enter numbers` | single | 2 → 1 | `lib/conversion_row.rb:165` | ported ⚠ | |
| 8 | — | `Enter numbers…` | single | 2 → 1 | `lib/conversion_row.rb:168` | ported ⚠ | |
| 9 | — | `Invalid input` | single | 4 → 4 | `lib/window.rb:112`, `:150`, `:172`, `:173` | ported | |
| 10 | — | `%(in_count)d bit` | plural | 1 → 1 | `lib/window.rb:313` (hand) | ported | |
| 11 | — | `%(out_count)d bit` | plural | 1 → 1 | `lib/window.rb:322` (hand) | ported | |
| 12 | — | `Octal` | single | 1 → 1 | `lib/conversion_row.rb:23` | ported | |
| 13 | — | `Decimal` | single | 1 → 1 | `lib/conversion_row.rb:24` | ported | |
| 14 | — | `Hexadecimal` | single | 1 → 1 | `lib/conversion_row.rb:25` | ported | |
| 15 | — | `Other` | single | 1 → 1 | `lib/conversion_row.rb:26` | ported | |
| 16 | — | `bits` | single | 1 → **0** | — | **gap** | `bits` |

Rows 7 and 8 are flagged, not gaps: the key is in the catalogue, and the 2→1
drop is `ConversionRow` being one class built twice. Accounted for in
`.reports/component-parity.md`, which shows `Gtk.Entry` at 2 upstream and 2 in
the port. The flag comes off there, not here.

Row 16 is the one real gap. `src/window.py:48` carries
`# Translators: this string is used to describe how many bits there are.` over
`bits_text = _("bits")`. The variable is never used upstream either, but
`xgettext` extracted it, it sits at `po/binary.pot:90`, and 32 translators
have translated it. The port emits nothing for it.

`Binary` (the base name) is asked for out of a *domain* called `Number base`,
not a context: upstream `src/window.py:52` writes
`dgettext("Number base", "Binary")` and the port writes
`d_('Number base', 'Binary')` (`lib/conversion_row.rb:22`). No catalogue
defines that domain on either side, so the string stays English in both.
Faithful, and deliberately so — reported here because a reader will otherwise
"fix" it.

## src/shortcuts-dialog.blp → lib/main.rb (5 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 17 | shortcut window | `General` | single | 1 → 1 | `lib/main.rb:227` (hand) | ported |
| 18 | shortcut window | `New Window` | single | 1 → 1 | `lib/main.rb:33` + `:230` (hand) | ported |
| 19 | shortcut window | `Close Window` | single | 1 → 1 | `lib/main.rb:34` + `:230` (hand) | ported |
| 20 | shortcut window | `Show Shortcuts` | single | 1 → 1 | `lib/main.rb:35` + `:230` (hand) | ported |
| 21 | shortcut window | `Quit` | single | 1 → 1 | `lib/main.rb:36` + `:230` (hand) | ported |

## src/preferences.blp → lib/main.rb (1 message)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 22 | — | `Preferences` | single | 1 → 1 | `lib/main.rb:214` | ported |

## src/main.py → lib/main.rb (1 message)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 23 | — | `translator-credits` | single | 1 → 1 | `lib/main.rb:206` | ported |

## data/…desktop.in → data/…desktop.in (3 messages)

Byte-identical file. `Binary`, `Convert numbers between bases`,
`binary;decimal;hexadecimal;base;convert;` — all three ported.

## data/…metainfo.xml.in → data/…metainfo.xml.in (5 messages)

Byte-identical file. `Binary`, `Convert numbers between bases`,
`A small and simple app used to convert between different hexadecimal and binary numbers`
and the three screenshot captions — all ported. (`Binary` and
`Convert numbers between bases` are shared with the desktop file and counted
once each.)

## Extra

- `not in any catalogue` — `test/test_i18n.rb:58`, a negative assertion that
  an unknown msgid comes back unchanged. It is in a test file, not shipped,
  and the port's `rake pot` would extract it because `po/POTFILES` does not
  list `test/`. Not parity work and English-only forever if it ever ships.

---

## `rake pot` destroys 288 translations — **closed in round 2**

Closed by writing every msgid out as a literal at its call site and then
running the task. What changed:

- `lib/main.rb` `#general_shortcuts` — five separate
  `c_('shortcut window', …)` calls, the `SHORTCUTS` table and
  `SHORTCUT_CONTEXT` deleted.
- `lib/window.rb` `#input_row` / `#output_row` — the plural forms are now
  `n_('%(in_count)d bit', '%(in_count)d bits', count)` and the `out_count`
  pair, one lambda per row; `ConversionRow#refresh_bits` calls the lambda, so
  the splat is gone.
- `lib/main.rb` `#about_dialog` — the summary is inline; the `SUMMARY`
  constant is deleted.
- `lib/conversion_row.rb` `.placeholder_text` / `.accessible_label` — two
  msgids that were inside a `#{}` interpolation in the builder heredoc, which
  xgettext also cannot see. Found by running the task: the first run marked
  exactly those two obsolete in 29 catalogues.
- `ConversionRow::BITS_TEXT` — upstream's dead `bits_text = _("bits")`
  (`src/window.py:48`), reproduced so the 30th msgid stays in the catalogues.

The task itself could not run either, for a reason the first draft did not
find: GNU `xgettext` hands a `.rb` file to `rxgettext`, from the gettext
*gem*, which this shell does not have — `xgettext: rxgettext subprocess
failed`. The task now reads the Ruby sources as Python and the data files
through xgettext's ITS rules, concatenating the two with `msgcat`
(FINDINGS.md section 9).

Verified after the change: `po/binary.pot`'s `(msgctxt, msgid)` set is
identical to upstream's, and the `#~ msgid` count is unchanged in all 32
`.po` files — nothing was marked obsolete. The 288 translations are still
there, and `rake pot` is safe to run.

### What the finding said


`Rakefile:196` runs:

```
xgettext … --keyword=_ --keyword=n_:1,2 --keyword=c_:1c,2 --keyword=d_:2 \
  --output=po/binary.pot --files-from=po/POTFILES
```

and then `msgmerge --update --backup=none po/<lang>.po po/binary.pot` for
every one of the 32 languages (`Rakefile:201`).

`xgettext` cannot resolve a Ruby constant any better than the census could.
Of the 24 messages the port emits from `lib/`, **nine** reach gettext only
through a constant or a splat:

| msgid | why xgettext misses it |
|---|---|
| `shortcut window`␄`General` | `c_(SHORTCUT_CONTEXT, 'General')` — context is a constant |
| `shortcut window`␄`New Window` | `c_(SHORTCUT_CONTEXT, title)` over the `SHORTCUTS` table |
| `shortcut window`␄`Close Window` | ditto |
| `shortcut window`␄`Show Shortcuts` | ditto |
| `shortcut window`␄`Quit` | ditto |
| `%(in_count)d bit` | `n_(*@bit_plural, …)` — splatted ivar |
| `%(out_count)d bit` | ditto |
| `A small and simple app…` | `_(SUMMARY)` — constant |

Running `rake pot` therefore writes a `binary.pot` with those nine missing,
and `msgmerge --update` then marks all nine **obsolete (`#~`)** in every one
of the 32 `.po` files. That is **9 × 32 = 288 donated translations** moved out
of the catalogue by a single `rake` invocation, silently, with the English
still rendering correctly.

The fix is not to the Rakefile. It is to write the context and the msgids as
literals at each call site — `c_('shortcut window', 'New Window')` four times,
`n_('%(in_count)d bit', '%(in_count)d bits', n)` inline — so that `xgettext`
and the census both read what gettext reads at runtime. Until then **do not
run `rake pot`**, and this ledger's 29 `ported` rows depend on a hand census
that the project's own tooling contradicts.

## What could not be checked

**Round 2: both of these were checked.** `nix develop` has `msgfmt`,
`xgettext`, `msgcat` and `glib-compile-schemas`; what it lacks is a working
`rake` wrapper (FINDINGS.md section 10) and a display (section 11), so the
tasks were run through rake's own `exe` under `xvfb-run -a`.
`rake translations` compiled all 32 catalogues with no `msgfmt` diagnostics,
and `test/drive_translated.rb` ran the window under `LANGUAGE=de` with all
eight on-screen assertions passing — including `6 Bits` from the plural form
and `Ungültige Eingabe` from the tooltip. The two items below are the
first draft's text, kept for the record.

- **`msgfmt` is not installed in this shell**, so `rake translations` could
  not run, `locale/` does not exist in the working tree, and the claim that
  32 `.mo` files compile cleanly is **unverified**. `msgfmt -c` on each `.po`
  is also unrun.
- **The app was not run under a non-English locale.**
  `test/drive_translated.rb` exists and asserts eight German strings on
  screen, including the placeholder `Zahl eingeben`; it could not be executed
  (`minitest` and the GLib tools are absent). So the last and only
  non-document check — that the inherited catalogues actually reach a user —
  is **open**.
- `xgettext` is absent, so the `rake pot` finding above is derived by reading
  the keyword list against the call sites rather than by running the command.
  It is not speculative — the nine call sites and the four `--keyword` forms
  are both in the repository — but nobody watched the 288 entries become
  obsolete.

`29/30 messages · 37/41 occurrences · 32/32 languages · 882 strings · de
NOT verified on screen`.
