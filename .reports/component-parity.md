# Component parity — binary-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e96066b` |
| Port | `ruby` @ `0dfda24` |
| Round | 6 |
| Components compared | 17 |
| Runtime gate | `test/drive_window.rb` **205 of 205**, `DRIVE OK`; `test/drive_translated.rb` **8 of 8**; `test/high_contrast_check.rb` **6 of 6** — all re-run this round through `nix develop --command xvfb-run -a` |
| **Open gaps** | **2** (7, 8 — gaps 1-6 and 9 closed since round 5, re-verified live this round) |
| Verdict | **not clean** |

Everything in `.reports/component-identification.md`'s census exists in the
port. The gaps below are behavioural: places where the widget is there and
does something other than what upstream's does, and places where the component
exists in the tree but cannot be reached by anyone who installs the port.

---

## 1. NEW — base-prefixed input is a user-visible error the port invents

**Upstream converts `0b11`, `0o17` and `0x1F`. The port rejects all three.**

`src/lib/get_answer.py:66` validates each dot-separated part with
`int(x, in_base)`. Python's `int()` accepts the prefix that matches the base it
is given:

```
$ python3 -c "print(int('0b11',2), int('0o17',8), int('0x1f',16))"
3 15 31
```

So upstream, with the input base on Binary, converts `0b11` to `3`; on
Hexadecimal it converts `0x1F` to `31`; and when the two bases are equal it
takes the early `if in_base == out_base: return input` branch and echoes
`0b11` back with **no error styling at all**.

The port gates on a regex instead (`lib/converter.rb:52`,
`Converter.valid?`), which allows only digits legal in the base plus single
underscores. Measured this round:

| input | bases | upstream | port |
|---|---|---|---|
| `0b11` | 2 → 10 | `3` | `char` → `error` class + "Invalid input" tooltip |
| `0B11` | 2 → 10 | `3` | `char` |
| `0o17` | 8 → 10 | `15` | `char` |
| `0x1F` | 16 → 10 | `31` | `char` |
| `0b11` | 2 → 2 | `0b11`, no error | `char_dual` → **both** entries flagged |

Three invented error states and one invented *double* error state, on input a
user can reach by typing. `Integer("0b11", 2)` in Ruby returns `3`, so the
conversion half of the port already behaves correctly — only the validity gate
diverges.

Two aggravations, both carried into
`.reports/accountability-ensurance.md`:

- The comment above `Converter.valid?` states the opposite of the measured
  fact: *"No sign, no `0x` prefix and no whitespace: `int()` takes those only
  in base 10 or with a matching prefix, neither of which can reach here."* A
  matching prefix is exactly what reaches here, in all three of the app's
  non-decimal bases.
- `test/test_converter.rb:54-57`, named
  `test_prefixes_int_would_not_accept_in_these_bases`, asserts
  `Converter.answer('0x1f', 16, 10) == 'char'` and
  `Converter.answer('0b11', 2, 10) == 'char'`. The suite is green **because**
  it pins the defect.

Owed: `Converter.valid?` must accept the base-matching prefix the way
`int(x, base)` does — `0b`/`0B` in base 2, `0o`/`0O` in base 8, `0x`/`0X` in
base 16 — and the two assertions and the comment have to be rewritten against
measured Python, not remembered Python. Python's `int()` also strips leading
and trailing whitespace other than the space character the app rejects first
(`int('\t10', 2) == 2`); the same gate rejects that too.

## 2. NEW — `change_output_base` does work upstream's exception skips

`src/window.py:93-100`:

```python
def change_output_base(self, *kwargs):
    try:
        self.input_handler()
        self.toggle_bit_counter()
        self.toggle_base_spin()
        self.editable = True
    except:
        return
```

`input_handler` can raise: with a `+` in the input, `get_answer` reaches
`src/lib/get_answer.py:57`'s `split_input('')`, which calls a list and raises
`TypeError`. Inside `change_output_base` that exception is swallowed by the
bare `except: return`, so **`toggle_bit_counter`, `toggle_base_spin` and
`editable = True` never run** — the bit-counter and spin-button visibility
stay as they were for the old base, and `editable` keeps whatever value
`input_handler` left it with (`False`, set on its first line).

The port models the raise as `Converter::ABORT`, a return value, so
`BinaryWindow#input_handler` returns normally and `#change_output_base`
(`lib/window.rb:63-67`) always goes on to `refresh_chrome` and
`@editable = true`. With `+5` in the input entry, switching the output base
to or from Binary updates the bit button's visibility in the port and leaves it
stale upstream, and `@editable` ends up `true` here and `false` there — which
also means the output entry accepts the next edit in the port and ignores it
upstream.

No check covers it: `test/test_converter.rb` tests `ABORT` at the `Converter`
level only, and `test/drive_window.rb` never changes a base with a `+` in the
entry.

## 3. NEW — the installed gem has no GSettings schema, and aborts

`lib/settings.rb` calls `Gio::Settings.new('io.github.fizzyizzy05.binary')` the
first time `BinaryWindow#restore_bases` runs, i.e. on every window. GLib
**aborts the process** (`g_error`) when the schema id is not installed; there
is no exception to rescue.

The schema reaches a checkout through `rake schemas`, which writes
`data/schemas/gschemas.compiled`, and `exe/binary` puts that directory on
`GSETTINGS_SCHEMA_DIR` when the file exists. But:

- `.gitignore:6` ignores `data/schemas/gschemas.compiled`, so it is never
  committed;
- `rake build` depends on `:translations` only (Rakefile), not on `:schemas`,
  so a gem packed from a clean checkout carries
  `data/schemas/io.github.fizzyizzy05.binary.gschema.xml` and no compiled
  schema;
- nothing installs the schema into a system schema directory either (gap 6
  below), and nothing compiles one at runtime.

So `gem install binary-rb && binary` aborts before the window appears. The
drive run proves nothing about this: it runs from the working tree, where
`gschemas.compiled` happens to exist because `rake schemas` was run by hand.
Owed: `task build: :schemas` as well as `:translations`, the compiled file in
`spec.files`, and a check that runs `exe/binary` with `GSETTINGS_SCHEMA_DIR`
unset and the compiled schema moved aside.

## 4. CARRIED (round 3 gap 4) — `:handles_command_line` accepts arguments upstream rejects

`src/main.py:33` passes `flags=Gio.ApplicationFlags.DEFAULT_FLAGS`. A
`GApplication` with neither `HANDLES_OPEN` nor `HANDLES_COMMAND_LINE` refuses a
non-option argument: it prints *"Application does not take command line
arguments"* and exits 1. `lib/main.rb` uses `:handles_command_line`, and
`#handle_command_line` scans the arguments for `--new-window`/`-w` and
otherwise calls `app.activate`.

Measured this round, in the dev shell:

| invocation | port | upstream |
|---|---|---|
| `binary nonsense-argument` | window opens, process stays up (exit 124 under a 60s timeout) | message on stderr, exit 1 |
| `binary --nonsense` | `Unknown option --nonsense`, exit 1 | same |
| `binary --help` | usage incl. `-w, --new-window`, exit 0 | same |

Still an invented success path. The flag is needed for nothing upstream does —
`--new-window` is carried by `do_handle_local_options` + `register` +
`activate_action`, which the port already implements — so this is a
divergence, not a binding limitation (see
`.reports/accountability-ensurance.md`).

## 5. CARRIED (round 3 gap 6) — nothing installs `.desktop`, `.service` or metainfo

`data/io.github.fizzyizzy05.binary.desktop.in`,
`.service.in` and `.metainfo.xml.in` are committed byte-identical to upstream
and packed into the gem, and `@bindir@` in the service file is never
substituted by anything. Nothing copies any of the three into
`share/applications`, `share/dbus-1/services` or `share/metainfo`.

What a user loses, as against `data/meson.build` upstream:

- no launcher entry, so no icon in the shell and no `New Window` desktop action
  (the `.desktop` file declares `Actions=new-window;`);
- `DBusActivatable=true` cannot work, so `--gapplication-service` and D-Bus
  activation are dead;
- no app-store listing from the metainfo;
- the hicolor icons are never installed either — the port finds
  `vertical-arrows-symbolic` through a `Gtk::IconTheme` search path into its own
  source tree, which an installed gem still resolves, but the application icon
  itself (`Gtk::Window.set_default_icon_name`) has nothing to resolve against.

Drive checks 79 and 80 read the *files* and cross-check them against the live
application's actions and flags. They do not test an installation, and the
report must not be read as though they did.

## 6. CARRIED (round 3 gap 3) — `app.shortcuts` and `<primary>question` are invented

`src/main.py` creates `quit`, `about`, `preferences`, `close-window` and
`new-window`. It never creates `shortcuts`, although `src/window.blp`'s menu
item and all four `src/shortcuts-dialog.blp` items name `app.shortcuts`.
Upstream therefore ships a dead menu item and a dialog nothing opens.

The port creates the action and binds `<primary>question` to it
(`lib/main.rb` `ACTIONS`). The menu item working is defensible; the
accelerator is not derivable from anything upstream, and because
`Adw.ShortcutsItem` renders whatever the application has bound to the action,
the port's own shortcuts dialog *displays* a shortcut upstream's would show as
blank. Still open, still a divergence rather than a fix.

## 7. NEW — `Adw.PreferencesWindow` became an `Adw.PreferencesDialog`

`src/preferences.blp:4` is a `template $PrefsWindow: Adw.PreferencesWindow`
with `default-width: 400`, `default-height: 306`, `height-request: 200`, and
`src/preferences.py` sets `transient_for` on it: upstream's preferences are a
**separate top-level window** with its own titlebar and its own entry in the
window list. `lib/preferences_dialog.rb` builds an
`Adwaita::PreferencesDialog`, which presents as an `AdwDialog` inside the
parent window — a different widget, a different look and a different
interaction (it dims and traps the parent; it has no window-list entry; it
closes on Escape).

The substitution is explained in the file's own comment (the window class is
deprecated) and is probably the right engineering call, but it is a
user-visible divergence and it appears in no divergence list: `PORTING.md`
records it as neither a gap nor a blocker. `content-width`/`content-height`
carry the two default sizes; `height-request: 200` becomes
`set_size_request(-1, 200)`, which on an `AdwDialog` constrains the dialog
rather than a window. Owed: either the window class with its deprecation
accepted, or the divergence written into `PORTING.md` where the next reader
will find it.

## 8. NEW — narrowed `notify`, and two extra boxes

Two small structural divergences the regenerated inventory exposed:

- `src/window.blp` connects `notify => $change_input_base()` and
  `notify => $change_output_base()` to the **bare** `notify` signal, so every
  property change on either `DropDown` re-runs the handler — including
  `selected-item` immediately after `selected`, and including the model being
  set in `__init__`, which is how upstream's initial bit-counter and
  spin-button visibility gets computed at all. `lib/conversion_row.rb`
  connects `notify::selected`. The end state is the same for every base change
  a user can make, and `restore_bases` does the initial pass explicitly, so
  nothing observable differs today — but it is a narrower connection than the
  spec, and any future upstream handler that leans on another property
  notification would silently not fire here.
- `Gtk.Box` count is 6 upstream and 8 in the port:
  `ConversionRow#container` is a vertical box per row holding the CenterBox and
  the Entry, where upstream puts both straight into the content box. Spacing
  is 6 at both levels so the result looks identical; it is still two widgets
  of structure upstream's tree does not have.

## 9. NEW — the About dialog shows a description upstream's does not

`adw_about_dialog_new_from_appdata` sets `application-name`,
`application-icon`, `developer-name`, `version`, `release-notes`,
`release-notes-version`, `license-type`, `website`, `issue-url` and
`support-url` from the AppStream data. It does **not** set `comments`.
`lib/about_dialog.rb` sets

```ruby
about.comments = _('A small and simple app used to convert between different hexadecimal and binary numbers')
```

which puts a description paragraph under the app name that upstream's About
dialog does not show. The msgid is an existing one (it comes from the metainfo
`<description>`, which is in `po/POTFILES` on both sides), so translation
parity is unaffected — but the dialog has one more line of content than the
one being ported. The `support_url` the appdata path would have filled is
absent from the port, which is moot only because the metainfo declares no
`<url type="help">`.

---

## Verified at parity this round

Listed so the open gaps above are not read as the whole picture.

| Behaviour | Where checked |
|---|---|
| window geometry 360×390, minimum 360×294, title `Binary` untranslated | drive |
| ToolbarView / HeaderBar `show-title: false` / start MenuButton with `open-menu-symbolic`, `Main Menu` tooltip, `primary: true` | drive |
| primary menu: two sections, three items, exact labels and action names | drive |
| Clamp 600 / 1000; content box margins 30/30/30/60, spacing 6, `valign: center` | drive |
| arrow box: spacing 9, margins 18/12, `typing-label`, `vertical-arrows-symbolic` at `normal` | drive |
| both dropdowns: 5 base names, `Binary` out of the undefined `Number base` domain, `flat-dropdown`, Input/Output Base tooltips | drive + `test/drive_translated.rb` |
| both spin buttons: range 2–36, snap to ticks, increments 1/2, numeric, `margin-start: 6`, visible only on "Other" | drive |
| both entries: placeholder `Enter numbers`, accessible label `Enter numbers…`, `enable-undo: false` | drive |
| bit buttons: `bitLbl` + `flat`, `halign: start`, popover with a wrapping 30-char label, visible only when that row's base is Binary, insensitive while both digit counts are 0 | drive |
| live conversion both directions, the `@editable` ping-pong guard, uppercase normalisation, `monospace` on/off | drive + `test/test_converter.rb` |
| `error` class + `Invalid input` tooltip on one or both entries, and the `char_dual` echo | drive |
| `+` aborting the handler with nothing changed; `.` across unequal bases erroring; `bit_count`'s decimal tail | `test/test_converter.rb` |
| `input-base`/`output-base` written on close and restored on open | drive + `test/test_settings.rb` |
| 6 actions, 4 accelerators, About/preferences/shortcuts dialogs built fresh per activation and never shared between windows | drive |
| `style.css` and `style-hc.css` byte-identical; the high-contrast provider added and removed as `AdwStyleManager:high-contrast` flips, idempotently | `test/high_contrast_check.rb` |
| exit status: 1 for a rejected option, 0 for `--help` | drive + measured |
| all four data files and three icons byte-identical to upstream | `diff` against `origin/main` |

---

## Round 6 re-verification

All six closures `PORTING.md` claims for this ledger (gaps 1, 2, 3, 4, 5, 9)
were re-run live, not accepted from the prose:

| Gap | Re-verified how | Result |
|---|---|---|
| 1 — base-prefixed input | `test/test_converter.rb` assertions for `0b11`/`0o17`/`0x1F` read directly; `grep -n "0b1\|0o1\|0x1" test/test_converter.rb` | present, matches the Python measurements quoted |
| 2 — `change_output_base` skips on `ABORT` | `test/drive_window.rb:662` drives a literal `+` into the entry under `xvfb-run` | step passes live, in the 205 |
| 3 — gem ships no compiled schema | `rake schemas` run via the `unset BUNDLE_GEMFILE` workaround (see `test-parity.md` gap 3); `rake build` run end to end; `gem unpack pkg/binary-rb-0.1.0.gem` inspected | `data/schemas/gschemas.compiled` exists in the built tree **and** inside the unpacked gem |
| 4 — `:handles_command_line` | `test/drive_window.rb` steps for the stray-argument and `--new-window` cases, re-run | present in the 205, passing |
| 5 — desktop/service/metainfo not installed | `XDG_DATA_HOME=/tmp/xdgdata rake install_data` run for real | all three files land, service file's `Exec=` substituted with the real `Gem.bindir` |
| 9 — About dialog `comments` | `grep -n comments lib/about_dialog.rb` | no `about.comments =` line in the file |

All six hold. Gap 6 (half-closed: the accelerator is gone, the action stays)
is unchanged and still correctly recorded as a half-closure rather than a
closure — `lib/main.rb`'s `app.shortcuts` binds no accelerator, confirmed by
reading the action registration.

**Gaps 7 and 8 remain open**, and are not being excused: `component-parity.md`
itself records gap 7 as "a user-visible divergence: it dims and traps the
parent, has no window-list entry and closes on Escape" rather than waving it
through as a correspondence, and gap 8 as "nothing observable differs today"
without closing the row. Re-read against the house rule (`component-parity`
Step 6: "a unit has parity when every row says parity... one gap is not a pass
with a note") — correctly still **not clean**.

No new gap was found this round scanning the same unit list; `origin/main` is
unchanged at `e96066b`, so there is nothing new upstream to compare against.
