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

        # Built from nix/Gemfile rather than the root one. The root Gemfile's
        # `gemspec` directive needs binary-rb.gemspec sitting beside it on
        # disk, but pkgs.bundlerEnv copies only the Gemfile, Gemfile.lock and
        # gemset.nix it is given into a fresh Nix store directory — never the
        # gemspec, whatever else sits next to the Gemfile it read — so a
        # bundlerEnv built from the root Gemfile has wrapped binstubs (which
        # hard-set BUNDLE_GEMFILE to that gemfile-less copy) that die in
        # Bundler::Dsl#gemspec before they run anything. That reproduced under
        # `nix develop --command rake ...` specifically, since --command execs
        # the binary directly and never reaches the shellHook below.
        # nix/Gemfile has no `gemspec` directive to trip over in the first
        # place — it was already the intended gemdir for this bundlerEnv
        # (.gitignore has carried `!nix/Gemfile.lock` for exactly this since
        # before this fix), but flake.nix was still pointed at the root
        # Gemfile instead. See nix/Gemfile's own comment for why it also
        # carries rake/rubocop/minitest rather than leaving those to
        # nixpkgs' standalone packages the way rspec is handled below: both
        # `rake test` and `rake drive` shell out to a `ruby` subprocess that
        # inherits whichever `rake` process spawned it had as its GEM_HOME,
        # and a standalone rake's own gem set has no adwaita in it to inherit.
        gems = pkgs.bundlerEnv {
          name = "binary-rb-gems";
          ruby = pkgs.ruby_3_4;
          gemdir = ./nix;
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
            # `gems` carries rake, rubocop and (for `bundle`) bundler itself
            # as real wrapped binaries, not only the app's own adwaita/gtk4 —
            # see its definition above. Listing it is what puts their
            # `bin/rake`, `bin/rubocop` and `bin/bundle` on PATH.
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
            # The spec runner. rake and rubocop come from `gems` above
            # instead of nixpkgs' own standalone packages — see its comment
            # for why `rake test` and `rake drive` need that.
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
