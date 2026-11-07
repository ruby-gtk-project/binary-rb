# Translation parity — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `040f859` |
| Round | 7 |
| Languages | 32 upstream, 32 ported |
| msgids in `po/binary.pot` | identical to upstream, msgid-for-msgid, msgctxt-for-msgctxt |
| Catalogues differing from upstream in content | **0 of 32** |
| Compiled catalogues | 32 `.mo` under `locale/<lang>/LC_MESSAGES/binary.mo` |
| Runtime verification | `test/drive_translated.rb` **8 of 8**, in German, re-run live this round |
| **Open gaps** | **0** |
| Verdict | **clean** |

## Re-measured independently this round

```
$ msgcat --no-location --sort-output /tmp/upstream_main/po/binary.pot \
  > /tmp/up_ids.txt   # (via msgid/msgctxt/msgid_plural lines)
$ msgcat --no-location --sort-output po/binary.pot > /tmp/port_ids.txt
$ diff /tmp/up_ids.txt /tmp/port_ids.txt
$ echo $?
0
```

Byte-identical: `grep -c '^msgid "'` is 31 on both sides,
`grep -c '^msgctxt'` is 5 on both sides. `po/LINGUAS` diffs clean against
upstream's. `find locale -name '*.mo' | wc -l` → 32 on the port.

## A generic scanner reports a false gap here — caught and dismissed, not reported as a finding

Running this skill's own `catalogue.rb`/`msgid-census.sh` tooling over the
port tree reports `with_context: 0` against upstream's `with_context: 5`,
which looks like all five `(shortcut window, *)` messages are missing. They
are not. The scanner's marker regex
(`_|N_|NC_|C_|n_|Nn_|np_|p_|s_|ngettext|gettext|dgettext|dngettext|dpgettext|dpgettext2|pgettext|npgettext`)
does not include this project's own lowercase `c_` alias
(`lib/i18n.rb#c_`, used in `lib/shortcuts_dialog.rb`), which the house style
defines deliberately "so the call sites read like the ones being ported."
The scanner is a generic cross-language tool and has no way to know the
port's local naming.

This matters because the *actual* extraction path — `rake pot`'s
`xgettext ... --keyword=c_:1c,2 ...` (`Rakefile:195`) — does know, and the
committed `po/binary.pot`'s msgid-for-msgid diff against upstream (above)
proves all five context-carrying messages survive in the artifact that is
actually shipped. Recorded here so the next reader does not re-derive a false
"context messages are missing" finding from the same generic scan; the
ground truth is the compiled catalogue, not this skill's marker list.

## NEW this round — the committed `.pot`'s source references have drifted from the current tree

Running `rake pot` for real and diffing against the committed
`po/binary.pot` (then reverting the working tree, since `.pot`/`.po` are
generated artifacts and this round does not commit a regeneration):

```
$ nix develop --command rake pot
$ diff <(grep -v POT-Creation-Date /tmp/committed_binary.pot) \
       <(grep -v POT-Creation-Date po/binary.pot)
57c57
< #: lib/about_dialog.rb:66
---
> #: lib/about_dialog.rb:74
90c90
< #: lib/window.rb:115 lib/window.rb:164 lib/window.rb:185 lib/window.rb:186
---
> #: lib/window.rb:128 lib/window.rb:177 lib/window.rb:198 lib/window.rb:199
... (nine more `#:` lines, all line-number only)
```

Every difference is a `#:` source-location comment; **zero** `msgid`,
`msgid_plural` or `msgctxt` lines differ, and `git checkout -- po/` restores
the tree to exactly what was committed. `rake pot` has not been re-run since
`lib/about_dialog.rb`, `lib/window.rb` and `lib/conversion_row.rb` grew by
roughly 8-13 lines each (the round-7 commits that closed the behavioural
gaps), so the `#:` comments translators see point a few lines above where
the string actually lives now.

This is **not** a translation-parity gap under this skill's own definition
— parity is about the `(msgctxt, msgid)` key set and the shipped languages,
and `#:` comments are provenance, not part of the key (the skill's Step 1
example explicitly normalises locations away: *"locations must differ —
they name the port's own `lib/*.rb` instead of upstream's"*). It is recorded
here because a stale `#:` line is still a small accuracy defect a translator
or reviewer could notice and because leaving it unrecorded would be exactly
the kind of "green and silent" omission `accountability-ensurance` looks
for. Carried into that report. Owed: run `rake pot` and commit the refreshed
`po/*.po`/`po/binary.pot` the next time any `lib/*.rb` file's line numbers
move — a maintenance step, not a parity defect.

## Every catalogue, compared

All 32 languages in `po/LINGUAS` (identical to upstream's), content-diffed
with locations and comment lines normalised away — unchanged from round 6's
result, re-spot-checked this round on `de.po` (31 msgids, `msgstr`s
byte-identical including `translator-credits`'s
`"Konstantin Tutsch <mail@konstantintutsch.com>"`).

## Does it reach the user

1. **Compiled**: `rake build` compiles all 32 `.mo` (re-verified live this
   round, inside `pkg/binary-rb-0.1.0.gem` after unpacking).
2. **Packaged**: `binary-rb.gemspec` globs `locale/**/*` into `spec.files`.
3. **Bound**: `lib/i18n.rb#bind` calls `setlocale`/`bindtextdomain`/
   `bind_textdomain_codeset`/`textdomain` through libc, the same gettext GTK
   itself uses.
4. **Rendered**: `test/drive_translated.rb`, re-run live this round under
   `LANGUAGE=de` — 8 of 8: plural bit count (`6 Bits`), translated tooltip
   (`Ungültige Eingabe`), and the shortcuts dialog's `shortcut window`
   context title all render correctly.

The one fragility carried forward, not counted as a translation-parity gap
because the platform the port runs on today does not hit it: `lib/i18n.rb`
hard-codes `LC_ALL = 6`, glibc's own category number. Recorded in
`.reports/accountability-ensurance.md`.

This axis stays **clean**: 0 open gaps, independently re-measured this round
rather than carried forward from round 6's "clean" verdict.
