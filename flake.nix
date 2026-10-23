# nix-packages

# Copyright © Josep Bigorra <jjbigorra@gmail.com>

# nix-packages is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# nix-packages is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with nix-packages.  If not, see <https://www.gnu.org/licenses/>.

{
  description = "jjba23's Nix package set: Guile libraries and applications";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # One input per project, pinned by flake.lock.  `flake = false' because only
    # the source tree is wanted: each package is built with that project's own
    # expression, so this file never restates how something is built and the
    # two cannot drift apart.
    araneola = { url = "git+https://codeberg.org/jjba23/araneola"; flake = false; };
    bewaking = { url = "git+https://codeberg.org/jjba23/bewaking"; flake = false; };
    hygguile = { url = "git+https://codeberg.org/jjba23/hygguile"; flake = false; };
    iter-vitae = { url = "git+https://codeberg.org/jjba23/iter-vitae"; flake = false; };
    kracht = { url = "git+https://codeberg.org/jjba23/kracht"; flake = false; };
    lambdock = { url = "git+https://codeberg.org/jjba23/lambdock"; flake = false; };
    lenkesamler = { url = "git+https://codeberg.org/jjba23/lenkesamler"; flake = false; };
    maak = { url = "git+https://codeberg.org/jjba23/maak"; flake = false; };
    mutastructura = { url = "git+https://codeberg.org/jjba23/mutastructura"; flake = false; };
    olive-css = { url = "git+https://codeberg.org/jjba23/olive-css"; flake = false; };
    orgwebalchemy = { url = "git+https://codeberg.org/jjba23/orgwebalchemy"; flake = false; };
    scriba = { url = "git+https://codeberg.org/jjba23/scriba"; flake = false; };
    veritas = { url = "git+https://codeberg.org/jjba23/veritas"; flake = false; };

    # Dependencies nixpkgs has no package for yet: the branches of the fork that
    # add them, read exactly the way bewaking, hygguile and mutastructura read
    # them in their own flakes.  Each input goes away with its entry in
    # `sources' below, once the branch is merged and nixos-unstable has it.
    guile-uuid-src = { url = "github:jjba23/nixpkgs/guile-uuid-init"; flake = false; };
    guile-dbi-src = { url = "github:jjba23/nixpkgs/guile-dbi-init"; flake = false; };
    guile-dbd-sqlite3-src = { url = "github:jjba23/nixpkgs/guile-dbd-sqlite3-init"; flake = false; };
    guile-dbd-mysql-src = { url = "github:jjba23/nixpkgs/guile-dbd-mysql-init"; flake = false; };
    guile-dbd-postgresql-src = { url = "github:jjba23/nixpkgs/guile-dbd-postgresql-init"; flake = false; };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      # x86_64-darwin is gone on purpose: nixpkgs 26.11 dropped it, so listing
      # it here would make evaluation fail for every consumer of the set.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = lib.genAttrs systems;

      # Attribute name -> the input it comes from, and the expression to call
      # inside it.  The names are the ones nixpkgs uses (`guile-veritas'), so
      # that the overlay replaces an older nixpkgs copy in place rather than
      # adding a second package under a different name.
      sources = {
        # Dependencies first, since several projects below need them.
        guile-uuid = { repo = "guile-uuid-src"; expr = "pkgs/by-name/gu/guile-uuid/package.nix"; };
        guile-dbi = { repo = "guile-dbi-src"; expr = "pkgs/by-name/gu/guile-dbi/package.nix"; };
        guile-dbd-sqlite3 = { repo = "guile-dbd-sqlite3-src"; expr = "pkgs/by-name/gu/guile-dbd-sqlite3/package.nix"; };
        guile-dbd-mysql = { repo = "guile-dbd-mysql-src"; expr = "pkgs/by-name/gu/guile-dbd-mysql/package.nix"; };
        guile-dbd-postgresql = { repo = "guile-dbd-postgresql-src"; expr = "pkgs/by-name/gu/guile-dbd-postgresql/package.nix"; };

        araneola = { repo = "araneola"; expr = "default.nix"; };
        guile-bewaking = { repo = "bewaking"; expr = "default.nix"; };
        guile-hygguile = { repo = "hygguile"; expr = "default.nix"; };
        guile-kracht = { repo = "kracht"; expr = "default.nix"; };
        guile-olive-css = { repo = "olive-css"; expr = "default.nix"; };
        guile-orgwebalchemy = { repo = "orgwebalchemy"; expr = "default.nix"; };
        guile-scriba = { repo = "scriba"; expr = "default.nix"; };
        guile-veritas = { repo = "veritas"; expr = "default.nix"; };
        iter-vitae = { repo = "iter-vitae"; expr = "default.nix"; };
        lambdock = { repo = "lambdock"; expr = "package.nix"; };
        lenkesamler = { repo = "lenkesamler"; expr = "default.nix"; };
        maak = { repo = "maak"; expr = "default.nix"; };
        mutastructura = { repo = "mutastructura"; expr = "default.nix"; };
      };

      # `final.callPackage', not `nixpkgs.legacyPackages.callPackage': one
      # package here depends on another (araneola needs guile-scriba), and in a
      # package set of its own that dependency has to be the sibling, not
      # whatever nixpkgs happens to ship.  Everything else resolves against the
      # nixpkgs the consumer brought, which is what an overlay is for.
      overlay = final: _prev:
        let
          built = lib.mapAttrs
            (_: source: final.callPackage "${inputs.${source.repo}}/${source.expr}" { })
            sources;
        in
        built // {
          # lambdock's own check phase aborts in a build sandbox: the tests treat
          # GTK's "cannot resolve icon 'utilities-terminal'" warning as fatal,
          # and a bare sandbox has no icon theme to resolve it from.  Giving the
          # check phase the icons keeps the tests running, which dropping them
          # would not.  Remove this once the project's tests bring their own.
          lambdock = built.lambdock.overrideAttrs (old: {
            nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [ final.adwaita-icon-theme ];
          });
        };

      # A package that does not support the platform (lambdock wants wayland and
      # gtk4, so it is linux-only) is simply absent there, instead of failing
      # `nix flake check' on a darwin machine.  `lib.meta.availableOn' reads the
      # derivation's own meta.platforms, so nothing is hard-coded here.
      packagesFor = system:
        let
          pkgs = nixpkgs.legacyPackages.${system}.extend overlay;
        in
        lib.filterAttrs
          (_: drv: lib.meta.availableOn pkgs.stdenv.hostPlatform drv)
          (lib.mapAttrs (name: _: pkgs.${name}) sources);

      # `nix run' for the packages that install a program; the rest are
      # libraries and have nothing to run.
      appsFor = system:
        lib.mapAttrs'
          (name: drv: lib.nameValuePair name {
            type = "app";
            program = "${drv}/bin/${drv.meta.mainProgram}";
          })
          (lib.filterAttrs (_: drv: drv.meta ? mainProgram) (packagesFor system));
    in
    {
      overlays.default = overlay;

      packages = forAllSystems packagesFor;

      # `nix flake check' builds the whole set; that is what CI runs.
      checks = forAllSystems (system: self.packages.${system});

      apps = forAllSystems appsFor;
    };
}
