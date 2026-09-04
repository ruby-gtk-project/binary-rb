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
          ];

          shellHook = ''
            export GI_TYPELIB_PATH="${pkgs.gtk4}/lib/girepository-1.0:${pkgs.libadwaita}/lib/girepository-1.0''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
          '';
        };
      }
    );
}
