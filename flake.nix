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

    # The Emacs packages.  Their repositories have no expression of their own,
    # so emacs.nix holds one for each; only the sources are wanted here.
    maak-el = { url = "git+https://codeberg.org/jjba23/maak.el"; flake = false; };
    veritas-el = { url = "git+https://codeberg.org/jjba23/veritas.el"; flake = false; };
    modusregel = { url = "git+https://codeberg.org/jjba23/modusregel"; flake = false; };
    tekengrootte-el = { url = "git+https://codeberg.org/jjba23/tekengrootte.el"; flake = false; };
    welkomscherm-el = { url = "git+https://codeberg.org/jjba23/welkomscherm.el"; flake = false; };
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

      # The five Emacs packages, from the sources above.  They are built inside
      # the consumer's `emacsPackages' rather than beside `packages', because
      # that is the set an elisp library belongs to: it is what `withPackages'
      # and `emacsPackagesFor' hand to Emacs.
      elispNames = [ "maak" "veritas" "modusregel" "tekengrootte" "welkomscherm" ];

      emacsOverlay = efinal: _eprev:
        import ./emacs.nix {
          inherit lib;
          emacsPackages = efinal;
          srcs = {
            maak = inputs.maak-el;
            veritas = inputs.veritas-el;
            modusregel = inputs.modusregel;
            tekengrootte = inputs.tekengrootte-el;
            welkomscherm = inputs.welkomscherm-el;
          };
        };

      # `final.callPackage', not `nixpkgs.legacyPackages.callPackage': one
      # package here depends on another (araneola needs guile-scriba), and in a
      # package set of its own that dependency has to be the sibling, not
      # whatever nixpkgs happens to ship.  Everything else resolves against the
      # nixpkgs the consumer brought, which is what an overlay is for.
      overlay = final: prev:
        let
          built = lib.mapAttrs
            (_: source: final.callPackage "${inputs.${source.repo}}/${source.expr}" { })
            sources;
        in
        built // {
          # The scope Emacs packages live in, extended in place, so that
          # `pkgs.emacsPackages.maak' and `pkgs.emacsPackages.withPackages'
          # both see the five below.  `prev' and not `final': the scope is being
          # defined in terms of itself here, which would not terminate.
          emacsPackages = prev.emacsPackages.overrideScope emacsOverlay;
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
          fromRepos = lib.mapAttrs (name: _: pkgs.${name}) sources;
          # Also listed in `packages', under an `emacs-' prefix, so that
          # `nix build .#emacs-maak' reaches one and `nix flake show' lists
          # them; the overlay is still the interface an Emacs user wants.
          fromEmacs = lib.mapAttrs'
            (name: drv: lib.nameValuePair "emacs-${name}" drv)
            (lib.genAttrs elispNames (name: pkgs.emacsPackages.${name}));
        in
        lib.filterAttrs
          (_: drv: lib.meta.availableOn pkgs.stdenv.hostPlatform drv)
          (fromRepos // fromEmacs);

      # Every Emacs package brings an ERT suite.  Run it, the way the project's
      # own maak.scm does and from the source tree rather than from the
      # installed copy, so that `nix flake check' tests the elisp and not only
      # that it byte-compiles.
      elispChecksFor = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          suites = {
            maak = { src = inputs.maak-el; file = "test/maak-test.el"; };
            veritas = {
              src = inputs.veritas-el;
              file = "test/veritas-test.el";
              # This suite asks whether `guile' exists on PATH and tests one way
              # if it does, the other if it does not; without it three tests
              # fail.  The two end-to-end cases stay skipped either way, since
              # their fixture wants the veritas launcher, which this set does
              # not install.
              tools = [ pkgs.guile ];
            };
            modusregel = { src = inputs.modusregel; file = "test/modusregel-test.el"; };
            tekengrootte = { src = inputs.tekengrootte-el; file = "test/tekengrootte-tests.el"; };
            welkomscherm = { src = inputs.welkomscherm-el; file = "test/welkomscherm-test.el"; };
          };
        in
        lib.mapAttrs'
          (name: suite: lib.nameValuePair "emacs-${name}-tests"
            (pkgs.runCommand "emacs-${name}-tests"
              { nativeBuildInputs = [ pkgs.emacs ] ++ (suite.tools or [ ]); }
              ''
                # The store is read-only and Emacs writes its native-compilation
                # cache under HOME, so test a copy of the tree.
                cp -r ${suite.src} source
                cd source
                HOME=$PWD emacs -Q --batch -L . -L test \
                  -l ${suite.file} -f ert-run-tests-batch-and-exit
                touch $out
              ''))
          suites;

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

      # `nix flake check' builds the whole set and runs every Emacs test suite;
      # that is what CI runs.
      checks = forAllSystems (system: self.packages.${system} // elispChecksFor system);

      apps = forAllSystems appsFor;
    };
}
