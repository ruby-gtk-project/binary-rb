# Translation parity — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `0dfda24` |
| Round | 6 |
| Languages | 32 upstream, 32 ported |
| msgids in `po/binary.pot` | identical to upstream, msgid-for-msgid |
| Catalogues differing from upstream in content | **0 of 32** |
| Compiled catalogues | 32 `.mo` under `locale/<lang>/LC_MESSAGES/binary.mo` |
| Runtime verification | `test/drive_translated.rb` **8 of 8**, in German, this round |
| **Open gaps** | **0** |
| Verdict | **clean** |

Round 3's four translation gaps are all closed, including gap 12, which round 4
left open. This is the only one of the five axes that is clean.

## msgid census

`.pot`, compared with locations normalised away (locations *must* differ — they
name the port's own `lib/*.rb` instead of upstream's `src/*.py` and `src/*.blp`):

```
$ diff <(msgcat --no-location --sort-output <(git show origin/main:po/binary.pot)) \
       <(msgcat --no-location --sort-output po/binary.pot)
$ echo $?
0
```

Byte-identical. That covers the msgids, the plural forms, the
`msgctxt` values, the `#,` flags (`python-format` on both sides — the
catalogues carry Python's `%(name)d` placeholders and `rake pot` scans the Ruby
as Python, so the flags still apply) and the `#.` translator instructions:

```
$ diff <(git show origin/main:po/binary.pot | grep '^#\.' | sort) \
       <(grep '^#\.' po/binary.pot | sort)
$ echo $?
0
```

All three instructions survive — `Replace "translator-credits" with your
names`, the `Keywords=` warning from the desktop file, and `this string is used
to describe how many bits there are`.

## Every catalogue, compared

All 32 languages in `po/LINGUAS` (which is itself identical to upstream's),
each compared with locations and comment lines normalised away:

```
langs=32 diffs=0
```

Not one msgstr differs, not one is newly fuzzy, not one msgid was dropped or
added. **Round 3's gap 12 — "`po/` is no longer byte-identical to upstream" —
is resolved**: the only thing that is not byte-identical is the `#:` source
references, which *cannot* be identical in a port and whose staleness was the
separate gap 13, closed in round 4. Content parity is exact.

## The msgids, and where each is asked for

| msgid | Upstream call site | Port call site |
|---|---|---|
| `Binary` (ctx. domain `Number base`) | `src/window.py:52` `dgettext` | `lib/conversion_row.rb` `d_` — same undefined domain, so still English both sides |
| `Octal`, `Decimal`, `Hexadecimal`, `Other` | `src/window.py:53-56` | `lib/conversion_row.rb` `BASE_NAMES` |
| `bits` | `src/window.py:48`, a class attribute nothing reads | `lib/conversion_row.rb` `BITS_TEXT`, dead in the same way rather than dropped and left obsolete in 32 files |
| `%(in_count)d bit` / `bits` | `src/window.py:212` `ngettext` | `lib/window.rb#input_row` |
| `%(out_count)d bit` / `bits` | `src/window.py:221` `ngettext` | `lib/window.rb#output_row` |
| `Invalid input` | `src/window.py` ×6 | `lib/window.rb` ×4 |
| `Main Menu`, `Input Base`, `Output Base` | `src/window.blp` | `lib/window.rb`, `lib/conversion_row.rb` |
| `Enter numbers`, `Enter numbers…` | `src/window.blp:75,80,136,141` | `lib/conversion_row.rb.placeholder_text`, `.accessible_label` — lifted out of the GtkBuilder heredoc on purpose, because a `_()` inside a `#{}` is a msgid `xgettext` cannot see |
| `New Window`, `_Keyboard Shortcuts`, `_About Binary` | `src/window.blp` menu | `lib/window.rb` menu sections |
| `Preferences` | `src/preferences.blp:4` | `lib/preferences_dialog.rb` |
| `General`, `New Window`, `Close Window`, `Show Shortcuts`, `Quit` (ctx. `shortcut window`) | `src/shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb`, one `c_` per item with the literal written out |
| `translator-credits` | `src/main.py:73` | `lib/about_dialog.rb`, with upstream's own `# Translators:` comment above it |
| `Convert numbers between bases`, `A small and simple app…`, `Name`, `Comment`, `Keywords`, screenshot captions, release notes | `data/*.desktop.in`, `data/*.metainfo.xml.in` | the same two files, shipped byte-identical |

`po/POTFILES` on the port names the port's own sources in upstream's order
(data files first, then code), which is why `msgcat --use-first` reproduces
upstream's msgid ordering.

## Does it reach the user

A catalogue that is perfect and never loaded is not a translation. Checked at
all four layers:

1. **Compiled**: `rake translations` produces 32 `.mo` files;
   `find locale -name '*.mo' | wc -l` → **32**.
2. **Packaged**: `binary-rb.gemspec` globs `locale/**/*` into `spec.files` and
   `task build: :translations` compiles them first, so a packed gem always
   carries all 32. (Round 3 gaps 8 and 10, closed in round 4 — still holds.)
3. **Bound**: `lib/main.rb` `LOCALE_DIRECTORIES` prefers `../locale` beside the
   source and falls back to `/usr/share/locale`; `I18n.bind` calls `setlocale`,
   `bindtextdomain`, `bind_textdomain_codeset` and `textdomain` through the same
   C gettext GTK itself uses, so plural rules and the `LANGUAGE` search list are
   the real ones.
4. **Rendered**: `test/drive_translated.rb`, re-run this round under
   `LANGUAGE=de`, asserts the bit counter reads `6 Bits` (plural form chosen by
   the catalogue, with `%(in_count)d` substituted), the invalid-input tooltip
   reads `Ungültige Eingabe`, and the shortcuts dialog's section title comes
   back out of the `shortcut window` context. 8 of 8.

The one fragility worth naming is not a translation gap but it lives here:
`lib/i18n.rb` hard-codes `LC_ALL = 6`. That is glibc's number. On a libc that
numbers the categories differently, `setlocale` is called with the wrong
category and all 32 correct catalogues render English with nothing to show that
anything went wrong. It is recorded in the file itself and carried as a
finding in `.reports/accountability-ensurance.md`, not counted as a
translation-parity gap, because on the platform the port is built and run on
the strings do arrive.

---

## Round 6 re-verification

Re-measured independently, not re-derived from round 5's "clean" verdict:

- Extracted `po/binary.pot` from both `origin/main` and `ruby`, parsed every
  `(msgctxt, msgid)` pair out of each by hand (not trusting `msgcat`, which
  this shell does not have — `which msgcat msgcomm` returns nothing): **30
  keys upstream, 30 in the port, set difference empty both directions.**
- `po/LINGUAS` on both sides: 32 entries, identical.
- Sampled `de.po`, `fr.po`, `es.po`, `ja.po` against
  `git show origin/main:po/<lang>.po`: identical `msgid` counts (31 each),
  and a line-level diff of `de.po` shows only reordering and the
  `POT-Creation-Date` timestamp — every `msgstr`, including
  `translator-credits`'s `"Konstantin Tutsch <mail@konstantintutsch.com>"`,
  is unchanged.
- `rake build` (run through the `unset BUNDLE_GEMFILE` workaround —
  `test-parity.md` gap 3) compiles all 32 `.po` files to
  `locale/<lang>/LC_MESSAGES/binary.mo` and packs them into the gem; verified
  by unpacking `pkg/binary-rb-0.1.0.gem` and listing `locale/*/LC_MESSAGES/*.mo`.
- `test/drive_translated.rb` re-run live: 8 of 8, `DRIVE OK`, in German.

**Flagged for `PORTING.md`, not for this report:** `PORTING.md`'s own "Open
gaps" section lists gap 12 — "`po/` is no longer byte-identical to upstream" —
as open under this report, citing it by number. The round-5
`translation-parity.md` already closes that exact gap in its own text
("Round 3's gap 12 … is resolved: the only thing that is not byte-identical is
the `#:` source references … Content parity is exact") and this report's own
header has always read **0 open gaps, verdict clean**. `PORTING.md` is
counting a gap its own cited source does not carry. That inconsistency is
reported in `.reports/accountability-ensurance.md`, since a status table that
disagrees with the document it cites is exactly the kind of claim that axis
exists to catch — it is not a translation defect.

This axis stays **clean**: 0 open gaps, re-verified by independent
re-measurement rather than by trusting the round-5 number.
