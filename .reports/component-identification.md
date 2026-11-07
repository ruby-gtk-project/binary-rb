# Component identification — binary

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` (unchanged since round 6; re-checked live this round) |
| Port | `ruby` @ `040f859` |
| Round | 7 |
| Upstream tree read via | `git archive origin/main` into `/tmp/upstream_main` — the ref is never checked out |

This round re-derives the census live rather than re-citing round 6's numbers,
because round 6's own committed `.reports/component-identification.md` was
itself one round stale by the time `040f859` landed (it still described the
`notify::selected` narrowing and the two open behavioural gaps that `040f859`
closed). Nothing here is carried forward unverified.

## Upstream units and their port counterparts

Unchanged from round 6 — `origin/main` has not moved, so the file mapping is
the same 17-component ledger:

| Upstream files | Port file |
|---|---|
| `src/window.py` + `src/window.blp` | `lib/window.rb` + `lib/conversion_row.rb` |
| `src/lib/get_answer.py` + `src/lib/bit_count.py` | `lib/converter.rb` |
| `src/main.py` (application, actions, accels, CSS install) | `lib/main.rb` |
| `src/main.py:70-77` (`on_about_action`) | `lib/about_dialog.rb` |
| `src/preferences.py` + `src/preferences.blp` | `lib/preferences_dialog.rb` |
| `src/shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` |
| `src/style.css`, `src/style-hc.css` | `lib/main.rb` `STYLE`, `HIGH_CONTRAST_STYLE` heredocs |
| `data/*.gschema.xml` | `lib/settings.rb` (+ `data/schemas/`) |
| `src/binary.in` | `exe/binary` |
| `po/**`, `data/**` | shipped as-is |

17 components, matching the live drive run's coverage count (re-measured this
round: `test/drive_window.rb` **214 of 214**, up from round 6's 205 — the
schema-missing-abort steps `[85]`-`[88]` and the three base-prefix window-level
steps `[17]`-`[22]` account for the difference, both added by `040f859` to
close `test-parity` gap 20/4).

## Widget census, unioned per component — re-measured this round

| Type | Upstream | Port | Note |
|---|---|---|---|
| `Adw.ApplicationWindow` | 1 | 1 | |
| `Adw.ToolbarView` | 1 | 1 | |
| `Adw.HeaderBar` | 1 | 1 | |
| `Adw.Clamp` | 1 | 1 | |
| `Gtk.WindowHandle` | 1 | 1 | |
| `Gtk.Box` | 6 | **8** | `ConversionRow#container` is a vertical box per row with no upstream opposite — explained below, not a gap |
| `Gtk.CenterBox` | 2 | 2 | |
| `Gtk.DropDown` | 2 | 2 | |
| `Gtk.SpinButton` | 2 | 2 | |
| `Gtk.Entry` | 2 | 2 | |
| `Gtk.MenuButton` | 3 | 3 | |
| `Gtk.Popover` | 2 | 2 | |
| `Gtk.Label` | 2 | 2 | |
| `Gtk.Image` | 1 | 1 | |
| `Adw.AboutDialog` | 1 | 1 | |
| `Adw.PreferencesWindow` | 1 | **0** | substituted by `Adw.PreferencesDialog` — see note |
| `Adw.PreferencesPage` | 1 | 1 | |
| `Adw.ShortcutsDialog` | 1 | 1 | |
| `Adw.ShortcutsSection` | 1 | 1 | |
| `Adw.ShortcutsItem` | 4 | 4 | |
| `Adw.Application` | 1 | **0** | substituted by `Gtk.Application` (bindings) |
| `Gtk.Window` (default icon name) | 1 | 1 | |

Two rows the component-parity skill's own rules resolve as **correspondences,
not gaps**, re-checked against the skill text this round rather than only
against last round's prose:

- `Adw.PreferencesWindow` → `Adwaita::PreferencesDialog` is "a widget replaced
  by a strictly newer equivalent, where upstream itself is behind"
  (`component-parity` SKILL.md, Step 1: "What is not a parity failure") —
  `Adw.PreferencesWindow` is deprecated upstream too, and the port's own
  comment in `lib/preferences_dialog.rb` says so. Recorded with the reason,
  which satisfies the rule; it is not waved through silently. It is still a
  **user-visible** difference (no window-list entry, dims and traps the
  parent, closes on Escape) and is carried that way in
  `component-parity.md`.
- The two extra `Gtk.Box`es are "a port file with no upstream file opposite
  it" that is "a factored-out repeat" — `ConversionRow#build` has to return
  one root widget, the shape every other extracted component in this house
  style uses. Explained, not unexplained; not a gap under Step 3's rule.

## Signals — re-measured this round

| Signal | Upstream | Port |
|---|---|---|
| `close-request` | `window.blp` → `on_close` | `lib/window.rb` |
| `changed` (Entry ×2, SpinButton ×2) | `window.blp` ×4 | `lib/conversion_row.rb` ×2, built twice |
| `notify` (DropDown ×2) | `window.blp` ×2, bare `notify` | **bare `notify`** ×1, built twice — **matches exactly now** |
| `activate` | `src/main.py` `do_activate` | `lib/main.rb` |
| `startup` | — (AdwApplication does it) | `lib/main.rb` |
| `handle-local-options` | `do_handle_local_options` | `lib/main.rb` |
| `notify::high-contrast` | — (AdwApplication resource loading) | `lib/main.rb` |

The `notify` row is a real change since round 6: `lib/conversion_row.rb:68`
now connects bare `notify`, not `notify::selected` — confirmed by reading the
line. Round 6's report correctly called the narrower connection "strictly
better, not a gap" per the skill's own rule, but the port went further and
matched upstream exactly. The `command-line` row from round 6's census is
gone: `lib/main.rb` no longer registers a `command-line` handler (confirmed —
`grep -n command-line lib/main.rb` returns nothing), because `:handles_command_line`
was replaced with `:default_flags`.

## Actions and accelerators — re-measured this round

| Action | Upstream accel | Port accel |
|---|---|---|
| `app.quit` | `<primary>q` | `<primary>q` |
| `app.close-window` | `<primary>w` | `<primary>w` |
| `app.new-window` | `<primary>n` | `<primary>n` |
| `app.about` | none | none |
| `app.preferences` | none | none |
| `app.shortcuts` | **never created** (`src/window.blp` menu item and `src/shortcuts-dialog.blp` both point at a non-existent action) | created, **no accelerator** (confirmed: `lib/main.rb` `ACTIONS['shortcuts'] => []`) |

The last row is unchanged since round 3 and is carried, not closed, in
`component-parity.md`.

## Menu items, pages, empty and error states

Unchanged from round 6's census, re-verified live this round through
`test/drive_window.rb`'s 214 checks — primary menu (2 sections, 3 items),
desktop action, preferences page (empty), shortcuts section (4 items), both
empty-entry and both error states, the `+`-abort state, and the
base-prefix-converts state (now driven at the window level, not only the
`Converter` unit, closing round 6's last test-parity coverage hole).

## Round 7 re-verification summary

- Upstream tree: `origin/main` still `e96066b`. No drift to rescan.
- Port tree: re-scanned at `040f859`, not at round 6's `0dfda24`.
- `test/drive_window.rb`: **214 of 214**, `DRIVE OK`, measured live this
  round under `nix develop --command xvfb-run -a ruby -Ilib -Itest`.
- The round-6 `.reports/component-identification.md` committed to the tree
  was itself stale by the time this round started — it still reported the
  `notify::selected` narrowing (closed) and 205 checks (now 214). This is the
  same failure mode `.reports/accountability-ensurance.md` round 6 found in
  `port-components.tsv`/`port-catalogue.yaml`: a generated-looking document
  that was not regenerated. Flagged there again this round.
