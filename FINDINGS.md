# FINDINGS — binary-rb

Defects and constraints in the Ruby GTK4 / Libadwaita bindings and in this
project's toolchain, found while porting upstream `binary` (Python 3 +
PyGObject + Blueprint) to Ruby on the `ruby` branch.

This file exists because a binding defect recorded in a code comment is a
defect nobody can find: the next person re-derives it, or writes around it and
calls the workaround a design. Every entry says what was tried, what happened,
and what the port does instead. None of them is an excuse for a missing
feature — where a feature is missing that is recorded in
`.reports/component-parity.md`, not here.

Environment: `nix develop` from `flake.nix` — ruby 3.4.9, gtk4 gem 4.3.9,
adwaita gem 4.3.9, glib2 gem 4.3.9, GTK 4.x and libadwaita from nixpkgs
unstable.

---

## 1. `Adwaita::Application` and `Adwaita::ApplicationWindow`

`Adwaita::Application` is unusable in the bindings, so the port uses
`Gtk::Application` (`lib/main.rb` `#app`). Two consequences the port pays for
by hand:

- `AdwApplication` initialises libadwaita for you. `Gtk::Application` does
  not, so `Adwaita.init` is called from the `startup` handler
  (`lib/main.rb`, `#build`) before anything touches `Adwaita::StyleManager`.
- `AdwApplication` auto-loads `style.css` and `style-hc.css` from the resource
  base path, keying the second on `AdwStyleManager:high-contrast`. The port
  installs two `Gtk::CssProvider`s and follows the property itself
  (`lib/main.rb` `#install_styles`, `#sync_high_contrast`).

`Adwaita::ApplicationWindow` does work, and `lib/window.rb` uses it.

## 2. `Gtk::Accessible#update_property` raises `NotImplementedError`

Setting an accessible label the way upstream's Blueprint does
(`src/window.blp:80`, `:141`) means `gtk_accessible_update_property`, and the
Ruby binding raises `NotImplementedError` marshalling its array argument.

The port builds each entry from a two-property `GtkBuilder` XML document
instead (`lib/conversion_row.rb` `#entry`, `.entry_ui`), where GtkBuilder
applies the `<accessibility>` block itself. Verified on screen:
`test/drive_window.rb` asserts
`Gtk.test_accessible_has_property(entry, Gtk::AccessibleProperty::LABEL)` for
both entries.

## 3. `Adwaita::ShortcutsItem.new(title, accelerator)` is the only two-argument form

`AdwShortcutsItem` has two string properties a constructor could take —
`accelerator` and `action-name` — and the bindings resolve
`new(String, String)` to the accelerator one, always. There is no way to ask
for the action-name form.

The port passes an empty accelerator and sets `action_name` afterwards
(`lib/main.rb` `#shortcut_item`), which is what makes the shortcuts dialog
show the accelerators the application actually binds.

## 4. `GLib::VariantDict#insert` with a plain Ruby value **segfaults**

```ruby
GLib::VariantDict.new(nil).insert('new-window', true)
# => Segmentation fault (core dumped), no Ruby-level exception
```

Wrapping the value works: `insert('new-window', GLib::Variant.new(true))`.
The crash is in `rg_insert` in `glib2.so`, so there is nothing to rescue — a
test that builds an options dict has to get this right first time
(`test/drive_window.rb` `#new_window_options`).

## 5. `Gio::Application#run` takes a C `argv`, and Ruby's `ARGV` is not one

`g_application_run` skips `argv[0]` as the program name. Ruby's `ARGV` has no
program name in it, so `app.run(ARGV)` silently drops the first argument: with
the main option registered, `binary --help` opened a window instead of printing
help, and `binary --new-window` was indistinguishable from a bare launch.

The port passes `[$PROGRAM_NAME, *ARGV]` (`lib/main.rb` `#run`), which is the
`sys.argv` upstream passes (`src/main.py:106`).

A second trap in the same place: `#build` returns the `Gtk::Application` so the
test driver can run it its own way, so the house launcher
`BinaryApp.new.build.run` would call **Gio's** `run` with no argv at all and
GLib would never see the options. `exe/binary` is
`BinaryApp.new.tap(&:build).run`.

## 6. `AdwDialog` has no default size

`Adwaita::PreferencesDialog#set_default_size` does not exist:
`respond_to?(:set_default_size)` is `false`. Upstream's
`src/preferences.blp:6-8` sets `default-width`/`default-height` on an
`Adw.PreferencesWindow`, which is a `GtkWindow`; the dialog's equivalent
properties are `content-width` and `content-height`, and a minimum stays an
ordinary `set_size_request`. `lib/main.rb` `#preferences_dialog` sets all
three, and `test/drive_window.rb` asserts them on the dialog that is on
screen.

## 7. `gtk_test_accessible_*` needs `GTK_A11Y=test`

Every `Gtk.test_accessible_has_property` call returns `false` under the
production accessibility backend, whatever the widget carries — the context
stores nothing a test can read back. `test/environment.rb` sets
`ENV['GTK_A11Y'] = 'test'`, and the accessible-label check in
`test/drive_window.rb` passes with it and failed without it. The widget was
correct the whole time; the assertion was lying.

## 8. No gettext in Ruby, so the catalogues are read through libc

There is no gettext in the standard library and none in the ruby-gnome
bindings, while every string GTK renders already goes through libc's
implementation. `lib/i18n.rb` binds to that with Fiddle — `dgettext`,
`dngettext`, the `\u0004` context separator — so the port reads the same
compiled `.mo` files GTK does, with the plural rules and the `LANGUAGE` search
list for free.

The constraint this leaves: **glibc does not expose the `LC_*` category
numbers anywhere Ruby can read them.** `setlocale` takes an integer, so
`lib/i18n.rb` carries `LC_ALL = 6`, which is glibc's number on the platform
the flake pins and is not portable to a libc that numbers them differently.
The gap that creates is written up at `lib/i18n.rb`; this entry is only why it
is awkward.

## 9. GNU `xgettext` cannot read Ruby without the gettext *gem*

Handed a `.rb` file, `xgettext` shells out to `rxgettext`, which the `gettext`
gem provides and this dev shell does not:

```
xgettext: rxgettext subprocess failed: No such file or directory
```

So `rake pot` could never have run here. The task now extracts the Ruby
sources with `--language=Python` and the `.desktop`/metainfo/gschema files with
xgettext's own ITS rules, then `msgcat`s the two (`Rakefile`, task `pot`).
Python is a true enough reading of these call sites — same `_()`/`n_()`/`c_()`
syntax, same quoting, same `%(name)d` placeholders, which is also why the
catalogues' `python-format` flags still apply. Confirmed: the regenerated
`po/binary.pot` carries exactly upstream's 30 messages, msgid for msgid.

Two things this reading will not see, and which therefore must not be written
that way:

- a gettext call inside a `#{}` interpolation (`lib/conversion_row.rb`
  `.placeholder_text` and `.accessible_label` exist because of this);
- a msgid that reaches the call as a constant, an instance variable or a splat
  (`lib/main.rb` `#general_shortcuts` and `lib/window.rb` `#input_row` /
  `#output_row` write theirs out as literals because of this).

## 10. CLOSED — The `rake` wrapper in the nix dev shell cannot start

`pkgs.bundlerEnv` builds its own `Gemfile`/`Gemfile.lock` pair into the store
and points `BUNDLE_GEMFILE` at it, but the root `Gemfile`'s `gemspec`
directive has no gemspec beside it there, so every wrapped binary — `rake`,
`bundle`, `rubocop` — dies in `Bundler::Dsl#gemspec` with
`There are no gemspecs at /nix/store/…-gemfile-and-lockfile`.

Closed by pointing `flake.nix`'s `gems` bundlerEnv at `gemdir = ./nix`
instead of the root Gemfile. `nix/Gemfile` carries no `gemspec` directive at
all — it already existed for this (`.gitignore` has carried
`!nix/Gemfile.lock` since before this fix) but `flake.nix` had never been
pointed at it — and now also carries `rake`, `rubocop` and `minitest`
alongside the app's own `adwaita`/`gtk4`, in the one bundlerEnv rather than a
second narrower one, because `rake test`'s `Rake::TestTask` and `rake
drive`'s `sh` calls both shell out to a `ruby` subprocess that inherits
whichever `rake` process spawned it had as its `GEM_HOME` — a `rake` kept
apart from `adwaita` leaves that subprocess unable to `require 'adwaita'`.
Measured: `nix develop --command rake -T`, `nix develop --command rubocop
--version` and `nix develop --command bundle --version` all start and print
cleanly; `nix develop --command xvfb-run -a rake test` and `nix develop
--command rake drive` both run to completion. `rake test` and `rake drive`
no longer need to be reported as "not run".

## 11. GTK needs a display; the driver's claim that it does not is wrong

`test/gtk_driver.rb:24-25` says the suite runs "with no display server at
all". It does not: `require 'gtk4'` raises `Gtk::InitError` ("failed to
initialize GTK") with `DISPLAY` and `WAYLAND_DISPLAY` unset, before any window
is made. The runs recorded in `.reports/test-parity.md` were made under
`xvfb-run -a`.

Until this round the fork's `flake.nix` carried no display at all, so there
was nothing to run them under: `xvfb-run: command not found`. The devShell now
carries `pkgs.xvfb-run`, and its banner names the commands that use it.

## 12. Four properties the UI has that the bindings will not read back

Found while widening `test/drive_window.rb` to cover every component. None of
them blocks the port — each one is a thing a *test* wanted to ask, and had to
ask another way.

| Missing | Effect | What the drive script does instead |
|---|---|---|
| `Gtk::CssProvider#to_string` | a loaded stylesheet cannot be read back, so "is `style.css` really on the display" has no direct answer | measures a `.bitLbl` label: the sheet sets a `font-size`, so the label's preferred width changes when the provider is added to or removed from the display |
| `Adwaita::StyleManager#high_contrast=` | `high-contrast` is read-only and libadwaita settles it at startup, so the high-contrast branch of `#sync_high_contrast` cannot be reached in-process | `test/high_contrast_check.rb` — the same harness with `ADW_DEBUG_HIGH_CONTRAST=1` set before `Adwaita.init`, spawned under `dbus-run-session` so it gets a bus of its own |
| `Gtk::Application#list_actions` | the registered action set cannot be enumerated | `#lookup_action` per name, against `BinaryApp::ACTIONS` |
| `Adwaita::PreferencesPage#find_group` | only `#get_group(index)` exists | `#get_group(0)` being nil is the "no groups" assertion |

## 13. A second instance on the same bus runs no steps and still prints `DRIVE OK`

`GtkDriver` reports success when nothing failed, and a run where *nothing
happened* has nothing failed in it. A second `BinaryApp` started on the same
session bus goes remote — `Failed to register: Timeout was reached`, then
`activate` never fires, no step runs, no check is recorded, and the report
reads `DRIVE OK`.

This bit once: the high-contrast child of finding 12 was spawned plainly and
"passed" without doing anything. Two things close it — the child runs under
`dbus-run-session`, and the parent asserts on the child's check *count*
(`6 of 6 checks passed`) and not only on its `DRIVE OK`.

---

## Upstream bugs found while porting, reproduced rather than fixed

These are upstream's behaviour, not binding defects. The port reproduces them
because its target is parity; each one needs raising upstream before it can be
closed here.

| Upstream | Behaviour | Port |
|---|---|---|
| `src/lib/get_answer.py:57` | `if '+' in input: split_input('')` calls a list, raises `TypeError`, and the handler dies mid-way: typing `+5` does nothing at all — no answer, no error styling, no bit count | `Converter::ABORT`, which `lib/window.rb` `#show_forwards` / `#show_backwards` deliberately do nothing with |
| `src/lib/get_answer.py:84` | any input containing `.` is refused unless the two bases are equal (upstream's own `# TODO: add separate calculations`), so `10.1` is an error on both sides | reproduced in `lib/converter.rb` `#convert` |
| `src/lib/bit_count.py` | the popover sum reads the `1` digits as binary place values while the `= n` tail reads the input as **decimal**, and the tail disappears for non-decimal input, trailing `" + "` and all | reproduced in `lib/converter.rb` `#bit_count` |
| `src/window.py:48` | `bits_text = _("bits")` is a class attribute nothing reads | reproduced as `ConversionRow::BITS_TEXT`, so the msgid stays in all 32 catalogues |
| `src/window.blp:182` + `src/main.py` | the menu offers `app.shortcuts` and upstream never creates that action, so upstream's menu item does nothing | the port creates the action and shows the dialog — a divergence, and an improvement, recorded in `.reports/component-parity.md` |
| `src/window.blp:112` | `notify => $change_output_base()` is connected to **every** property notification, so `set_model` in `src/window.py:67` runs the handler during `__init__` and `editable` is already `True` before the user can type | matched: `lib/window.rb` `#restore_bases` leaves `@editable` true, and `test/drive_window.rb` types into the output entry on a fresh window to pin it |
