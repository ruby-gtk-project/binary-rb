{
  description = "Ruby GTK4 development shell";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # ruby-gnome's extconf.rb walks every Requires.private in the .pc chain
        # of the library it binds, so a plain `bundle install` fails on
        # whichever transitive package the shell happens to be missing. Building
        # the gems through nix avoids the chase: nixpkgs already knows the C
        # dependencies of glib2, cairo, pango, atk and friends.
        #
        # It does not yet know gtk4, gdk4, gsk4 or adwaita, so those four are
        # supplied here. pkgs.gtk4 and pkgs.libadwaita propagate the rest of
        # their own chains.
        gnomeGem = extra: attrs: {
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = extra ++ (with pkgs; [
            libsysprof-capture
            pcre2
            libxdmcp
            libpthread-stubs
            # The pkg-config gem follows Requires.private, so the private
            # chains of glib, pango and gtk4 all have to be present too.
            libthai
            libdatrie
            fribidi
            util-linux
            libselinux
            libsepol
            graphene
            libepoxy
            wayland
            libxkbcommon
            vulkan-loader
            libx11
            libxext
            libxi
            libxcursor
            libxdamage
            libxrandr
            libxfixes
            libxinerama
            libxrender
            libxcb
          ]);
        };

        gems = pkgs.bundlerEnv {
          name = "binary-rb-gems";
          ruby = pkgs.ruby_3_4;
          gemdir = ./.;
          gemConfig = pkgs.defaultGemConfig // {
            gdk4 = gnomeGem [ pkgs.gtk4 ];
            gsk4 = gnomeGem [ pkgs.gtk4 ];
            gtk4 = gnomeGem [ pkgs.gtk4 ];
            adwaita = gnomeGem [ pkgs.libadwaita pkgs.gtk4 ];
          };
        };
      in
      {
        devShells.default = pkgs.mkShell {
          # glib.dev carries glib-compile-schemas and gettext carries msgfmt
          # and xgettext — `rake schemas` and `rake translations` need both.
          nativeBuildInputs = with pkgs; [ pkg-config wrapGAppsHook4 glib.dev gettext ];
          buildInputs = with pkgs; [
            gems
            gems.wrappedRuby
            bundix
            gtk4
            libadwaita
            gobject-introspection
            glib
            cairo
            pango
            gdk-pixbuf
            harfbuzz
            libyaml
            openssl
            gsettings-desktop-schemas
            adwaita-icon-theme
            # The spec runner. The gems in this shell are the app's runtime
            # closure rather than the full development bundle, so the suite
            # gets its own RSpec here.
            rubyPackages_3_4.rspec
            # gtk_init fails outright with no display on this machine — there
            # is no offscreen fallback — so every `ruby` invocation that
            # touches a widget goes through xvfb-run. Without this the drive
            # script dies in Gtk::Loader#call_init_function with
            # "failed to initialize GTK (Gtk::InitError)".
            xvfb-run
            # dbus-run-session. GApplication refuses to run at all without a
            # session bus, and the one app id can only be registered once per
            # bus, so the second instance test/drive_window.rb spawns (the
            # high-contrast run) needs a bus of its own.
            dbus
          ];

          shellHook = ''
            export GI_TYPELIB_PATH="${pkgs.gtk4}/lib/girepository-1.0:${pkgs.libadwaita}/lib/girepository-1.0''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}:${pkgs.adwaita-icon-theme}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
            # `ruby test/drive_window.rb` has to resolve `require "binary"`
            # against the checkout rather than an installed gem.
            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
            [ -d data/schemas ] && export GSETTINGS_SCHEMA_DIR="$PWD/data/schemas"
            # A parent direnv may export a BUNDLE_GEMFILE for another project,
            # which `bundle exec` in this shell would then try to satisfy.
            unset BUNDLE_GEMFILE BUNDLE_FROZEN

            # bundlerEnv's wrapped binstubs hard-set BUNDLE_GEMFILE to a store
            # Gemfile that has no gemspec beside it, so the wrapped `rake` and
            # `rubocop` both die in Bundler::Dsl#gemspec (FINDINGS.md 10).
            # Unsetting it in the shell does not help — the wrapper sets it
            # again at exec — so both are reached through plain ruby instead.
            rake() { ruby -e 'require "rake"; Rake.application.run' -- "$@"; }
            rubocop() { ruby -e 'require "rubocop"; exit RuboCop::CLI.new.run(ARGV)' -- "$@"; }
            export -f rake rubocop 2>/dev/null || true

            echo "binary devshell — ruby $(ruby -e 'print RUBY_VERSION')"
            echo "run the app:   xvfb-run -a ruby exe/binary"
            echo "drive the app: xvfb-run -a ruby test/drive_window.rb"
            echo "               xvfb-run -a ruby test/drive_translated.rb"
            echo "               xvfb-run -a ruby test/high_contrast_check.rb"
            echo "run the specs: xvfb-run -a ruby test/run_tests.rb"
            echo "lint:          rubocop"
          '';
        };
      }
    );
}
