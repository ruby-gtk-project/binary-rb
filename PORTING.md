# Porting status — binary-rb

Resume point for the next run. Upstream is the `origin/main` ref in this same
repository; read it with `git show origin/main:<path>`. The port lives on the
`ruby` branch and is written from scratch against upstream as the spec — the
upstream ref is never checked out and never merged.

| | |
|---|---|
| Upstream ref | `origin/main` @ `e96066b` |
| Port branch | `ruby` |
| Last audit round | 10 (`.reports/accountability-ensurance.md`) |
| Audit clean | **no** — 2 open findings on the last audit: finding 3 (gate-figure mismatch — the commissioning brief's claimed component count has moved unexplained, 13 → 14, against this port's own unchanged 17-component census) is still open; finding 5 (`PORTING.md` previously claimed "Audit clean: yes" while the accountability report's own verdict for the same round said "not clean") was a false green the same audit caught and corrected in-document. See `.reports/accountability-ensurance.md` |

## Upstream

Binary is a single-window GTK4/libadwaita number-base converter: two stacked
base-selector-plus-entry rows that convert into each other live, with a
per-entry bit-count popover for binary. It is implemented in Python 3
(PyGObject) with Blueprint (`.blp`) UI definitions and a Meson + GResource
build. The spec lives on the `origin/main` ref.

## Done

Components implemented and observed working (driven live this run via
`rake drive` and `test/run_tests.rb`, not re-cited from a prior report).

| Port path | Upstream source |
|---|---|
| `lib/window.rb` | `src/window.blp`, `src/window.py` |
| `lib/conversion_row.rb` | `src/window.blp`, `src/window.py` (one half of the window; instantiated twice) |
| `lib/converter.rb` | `src/lib/get_answer.py`, `src/lib/bit_count.py` |
| `lib/main.rb` | `src/main.py` (application, actions, accelerators, CSS, resource install) |
| `lib/about_dialog.rb` | `src/main.py:70-78` (About) |
| `lib/preferences_dialog.rb` | `src/preferences.py`, `src/preferences.blp` |
| `lib/shortcuts_dialog.rb` | `src/shortcuts-dialog.blp` |
| `lib/settings.rb` | `data/io.github.fizzyizzy05.binary.gschema.xml` |
| `lib/i18n.rb` | `po/` catalogues, via C `gettext` through Fiddle |
| `exe/binary` | `src/binary.in` (launcher) |
| `data/**` | upstream `data/**`, shipped byte-identical |
| `po/**` | upstream `po/**`, source references repointed at the port's own files |
| `Rakefile`, `binary-rb.gemspec` | `meson.build`, `data/meson.build`, `src/meson.build`, `po/meson.build`, `subprojects/blueprint-compiler.wrap` — the build, not a component: `rake translations`/`rake schemas` are the compile steps, `rake build` depends on both, and `rake install_data` installs the desktop entry, D-Bus service file and metainfo to `$XDG_DATA_HOME` |

## Runtime

Drive command run live this session:

```
nix develop --command xvfb-run -a rake drive
nix develop --command xvfb-run -a ruby test/run_tests.rb
```

- `drive_ok=true`
- `test/drive_window.rb` + `test/drive_translated.rb` (8/8) + `test/high_contrast_check.rb` (6/6) = **228 passed / 0 failed**, three `DRIVE OK` lines
- 14 components covered (gate-reported figure; this port's own census in `.reports/component-identification.md` and `.reports/component-inventory.md` counts 17 — see the open gate-figure mismatch under Open gaps, not resolved by this run)
- `test/run_tests.rb` (Minitest): **27 runs / 0 failures / 0 errors / 0 skips** (72 assertions)

## Not started

No upstream user-facing component is without a Ruby counterpart — every unit
listed in `.reports/upstream-components.tsv` has a port file. Nothing to list
here; outstanding items are tracked under Open gaps and Blockers.

## Open gaps

The last audit (`.reports/accountability-ensurance.md`, round 10) reported
**2 gap(s)**, verdict **clean=false**:

1. **Gate-figure mismatch (finding 3, open).** The runtime gate's claimed
   component count has moved across rounds with no explanation — 13, then
   14 — while this port's own documentation (`.reports/component-identification.md`,
   `.reports/component-inventory.md`) counts 17 components and that number
   has not changed. The 228-checks/0-failed figure is confirmed and
   reproduces live; the "14 components" figure attached to it does not
   trace to anything this port's own files compute, and the discrepancy is
   on the gate side, not something this run can resolve from inside the
   port.
2. **False green, found and fixed this round (finding 5).** Before round
   10's fix, `PORTING.md` claimed "Audit clean: yes" while
   `.reports/accountability-ensurance.md`'s own committed verdict for the
   same round read "not clean," for the unresolved reason above. The
   contradiction was real and is why this file's top-line verdict now says
   "no" rather than restating its own claim — it defers to the accountability
   report instead.

Component-parity's own four axes (`.reports/component-parity.md`) show 0
open items as of round 9's decision on gap 6 (below, under Blockers), but
that is narrower than the audit's overall verdict, which stays not-clean
for the reasons above.

## Blockers

Things that cannot be ported, and why.

- **Meson + GResource + blueprint-compiler.** `src/binary.gresource.xml`,
  `src/meson.build`, `data/meson.build`, `data/icons/meson.build`,
  `po/meson.build` and `subprojects/blueprint-compiler.wrap` have no
  counterpart in a gem. Widgets are built in Ruby, CSS is a heredoc in
  `lib/main.rb`, and the icon comes from a `Gtk::IconTheme` search path.
- **`Adw.AboutDialog.new_from_appdata`** needs the metainfo XML inside a
  compiled GResource bundle, which the port does not build. The About
  dialog is populated field-by-field by hand instead, reading the shipped
  `data/io.github.fizzyizzy05.binary.metainfo.xml.in` directly.
- **`Adwaita::Application` is broken in the Ruby bindings**, so the port
  uses `Gtk::Application`. That loses libadwaita's automatic resource
  loading of `style.css` and `style-hc.css`, which is why both stylesheets
  are installed manually from heredocs.
- **`Gtk::Accessible#update_property` raises `NotImplementedError`** in the
  bindings (it cannot marshal its array argument), so the two entries'
  accessible labels are applied through a small `Gtk::Builder` XML document
  in `lib/conversion_row.rb` rather than in code.
- **`src/__init__.py` and `src/binary.in`** are Python packaging and
  launcher plumbing with no user-facing component. `exe/binary` covers the
  equivalent job.
- **Upstream's `app.shortcuts` action is never created** in `src/main.py`,
  although the menu and the shortcuts dialog both reference it, so strict
  parity would mean shipping a dead menu item. The port deliberately
  diverges: it creates the action, with no accelerator bound (matching
  upstream, which binds none either). Decided permanently, round 9 (see
  `.reports/component-parity.md` gap 6): this stays a divergence rather than
  being reverted to reproduce upstream's dead reference.
