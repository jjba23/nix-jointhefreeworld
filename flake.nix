# nix-jointhefreeworld

# Copyright © Josep Bigorra <jjbigorra@gmail.com>

# nix-jointhefreeworld is free software, released under the MIT license: you
# may use, copy, modify, merge, publish, distribute, sublicense and sell it,
# provided that the copyright notice and this permission notice are included in
# all copies or substantial portions of it; see LICENSE.

# nix-jointhefreeworld is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  In no event shall the authors or copyright
# holders be liable for any claim, damages or other liability arising from it.

{
  description = "Jointhefreeworld's Nix package set: programs, Guile libraries, Emacs packages, an icon theme, and the packages nixpkgs is missing";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The two halves are flakes of their own, so either can be taken without the
    # other: `...?dir=emacs' brings five small repositories and no Guile
    # dependency at all, `...?dir=guile-deps' brings only the dependencies.  This
    # flake follows both and puts them back together, and `follows' keeps the
    # three of them on one nixpkgs rather than one each.
    guile-deps = { url = "path:./guile-deps"; inputs.nixpkgs.follows = "nixpkgs"; };
    emacs = { url = "path:./emacs"; inputs.nixpkgs.follows = "nixpkgs"; };

    # One input per project, pinned by flake.lock.  `flake = false' because only
    # the source tree is wanted: each package is built with that project's own
    # expression, so this file never restates how something is built and the
    # two cannot drift apart.
    araneola = { url = "git+https://codeberg.org/jjba23/araneola?ref=refs/tags/v0.0.5"; flake = false; };
    bewaking = { url = "git+https://codeberg.org/jjba23/bewaking?ref=refs/tags/v0.4.6"; flake = false; };
    ggg = { url = "git+https://codeberg.org/jjba23/ggg?ref=refs/tags/v0.16.4"; flake = false; };
    heks-toon = { url = "git+https://codeberg.org/jjba23/heks-toon?ref=refs/tags/v0.3.2"; flake = false; };
    hygguile = { url = "git+https://codeberg.org/jjba23/hygguile?ref=refs/tags/v2.7.6"; flake = false; };
    iter-vitae = { url = "git+https://codeberg.org/jjba23/iter-vitae?ref=refs/tags/v1.0.4"; flake = false; };
    kracht = { url = "git+https://codeberg.org/jjba23/kracht"; flake = false; };
    lambdock = { url = "git+https://github.com/jjba23/lambdock?ref=refs/tags/v0.21.1"; flake = false; };
    lenkesamler = { url = "git+https://codeberg.org/jjba23/lenkesamler?ref=refs/tags/v0.0.5"; flake = false; };
    maak = { url = "git+https://codeberg.org/jjba23/maak?ref=refs/tags/v0.14.0"; flake = false; };
    mutastructura = { url = "git+https://codeberg.org/jjba23/mutastructura?ref=refs/tags/v0.9.4"; flake = false; };
    olive-css = { url = "git+https://codeberg.org/jjba23/olive-css?ref=refs/tags/v0.6.7"; flake = false; };
    orgwebalchemy = { url = "git+https://codeberg.org/jjba23/orgwebalchemy?ref=refs/tags/v1.2.4"; flake = false; };
    scriba = { url = "git+https://codeberg.org/jjba23/scriba?ref=refs/tags/v0.4.5"; flake = false; };
    sift = { url = "git+https://github.com/jjba23/sift?ref=refs/tags/v1.13.0"; flake = false; };
    skeu-icons = { url = "git+https://codeberg.org/jjba23/skeu-icons?ref=refs/tags/v1.6.1"; flake = false; };
    veritas = { url = "git+https://codeberg.org/jjba23/veritas?ref=refs/tags/v0.9.0"; flake = false; };
  };

  outputs = { self, nixpkgs, guile-deps, emacs, ... }@inputs:
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
        araneola = { repo = "araneola"; expr = "default.nix"; };
        ggg = { repo = "ggg"; expr = "default.nix"; };
        guile-bewaking = { repo = "bewaking"; expr = "default.nix"; };
        guile-hygguile = { repo = "hygguile"; expr = "default.nix"; };
        guile-kracht = { repo = "kracht"; expr = "default.nix"; };
        guile-olive-css = { repo = "olive-css"; expr = "default.nix"; };
        guile-orgwebalchemy = { repo = "orgwebalchemy"; expr = "default.nix"; };
        guile-scriba = { repo = "scriba"; expr = "default.nix"; };
        guile-veritas = { repo = "veritas"; expr = "default.nix"; };
        heks-toon = { repo = "heks-toon"; expr = "package.nix"; };
        iter-vitae = { repo = "iter-vitae"; expr = "default.nix"; };
        lambdock = { repo = "lambdock"; expr = "package.nix"; };
        lenkesamler = { repo = "lenkesamler"; expr = "default.nix"; };
        maak = { repo = "maak"; expr = "default.nix"; };
        mutastructura = { repo = "mutastructura"; expr = "default.nix"; };
        sift = { repo = "sift"; expr = "default.nix"; };
        skeu-icons = { repo = "skeu-icons"; expr = "default.nix"; };
      };

      # The names the other two flakes own, so that this one can list their
      # packages next to its own without restating how to build them.
      depNames = [
        "guile-uuid"
        "guile-dbi"
        "guile-dbd-sqlite3"
        "guile-dbd-mysql"
        "guile-dbd-postgresql"
      ];

      elispNames = [
        "maak"
        "veritas"
        "modusregel"
        "tekengrootte"
        "welkomscherm"
      ];

      # The packages that install a program.  A list of names rather than a
      # filter over every derivation: `apps' should not have to force the whole
      # set to find out which ones have a `meta.mainProgram'.
      programNames = [
        "araneola"
        "ggg"
        "heks-toon"
        "iter-vitae"
        "lambdock"
        "lenkesamler"
        "maak"
        "mutastructura"
        "sift"
      ];

      # A project's own expression, called against whatever nixpkgs is asking
      # for the package, which is what lets the overlay replace a nixpkgs copy
      # instead of sitting beside it.
      buildProject = final: name:
        final.callPackage "${inputs.${sources.${name}.repo}}/${sources.${name}.expr}" { };

      # Everything this flake adds to nixpkgs: the dependencies, through the
      # guile-deps flake's overlay so their expression has exactly one home, and
      # the projects.  `final.callPackage' is what lets one of them need another
      # — araneola needs guile-scriba, and here it gets this set's scriba.  The
      # dependencies overlay only reads `final', hence the same value twice.
      packageSet = final:
        (guile-deps.overlays.default final final)
        // (lib.mapAttrs (name: _: buildProject final name) sources);

      packagesOverlay = final: prev: packageSet final;

      overlay = final: prev:
        (packagesOverlay final prev)
        // {
          # The scope Emacs packages live in, extended in place, so that
          # `pkgs.emacsPackages.maak' and `pkgs.emacsPackages.withPackages'
          # both see the five of the emacs flake.  `prev' and not `final': the
          # scope is being defined in terms of itself here, which would not
          # terminate.
          emacsPackages = prev.emacsPackages.overrideScope emacs.overlays.default;
        };

      # Nothing shadows anything here: one attribute, and every package under it
      # — `pkgs.jointhefreeworld.maak'.  The packages are built against a pkgs
      # that has the names, so one that needs a sibling still finds it.
      namespacedOverlay = final: prev:
        let pkgs = final.extend packagesOverlay;
        in { jointhefreeworld = packageSet pkgs; };

      # One overlay per package, so that `nixpkgs.overlays = [ ...overlays.maak ]'
      # puts exactly one name into `pkgs' rather than all eighteen.  The
      # dependencies are the guile-deps flake's own per-package overlays,
      # re-exported so that there is one way to ask for one of them.
      perPackageOverlays =
        lib.mapAttrs
          (name: _: (final: prev:
            let pkgs = final.extend packagesOverlay;
            in { ${name} = pkgs.${name}; }))
          sources
        // (builtins.removeAttrs guile-deps.overlays [ "default" ]);

      # Values here are lazy on purpose: asking for one package must not
      # evaluate the other twenty-two, so a project that breaks its own
      # expression takes down itself and nothing else.  `checks' below is where
      # the set is forced, because that is a check's job.
      packagesFor = system:
        let pkgs = nixpkgs.legacyPackages.${system}.extend overlay;
        in
        (lib.mapAttrs (name: _: pkgs.${name}) sources)
        // (lib.genAttrs depNames (name: pkgs.${name}))
        // (lib.listToAttrs
          (map (name: lib.nameValuePair "emacs-${name}" pkgs.emacsPackages.${name}) elispNames));

      checksFor = system:
        let
          pkgs = nixpkgs.legacyPackages.${system}.extend overlay;
          # Here, and only here, every package is forced: `availableOn' reads
          # each derivation's own meta.platforms, which is how a linux-only
          # package (lambdock wants wayland and gtk4) is left out on darwin
          # without a list of names to maintain.
          available = lib.filterAttrs
            (_: drv: lib.meta.availableOn pkgs.stdenv.hostPlatform drv)
            self.packages.${system};
        in
        available // emacs.checks.${system};

      appsFor = system:
        let pkgs = nixpkgs.legacyPackages.${system}.extend overlay;
        in
        lib.mapAttrs'
          (name: drv: lib.nameValuePair name {
            type = "app";
            program = "${drv}/bin/${drv.meta.mainProgram}";
            # Nix shows this in `nix run --help' and warns during `nix flake
            # check' when it is missing.
            meta = { description = drv.meta.description or name; };
          })
          (lib.filterAttrs
            (_: drv: drv.meta ? mainProgram)
            (lib.genAttrs programNames (name: pkgs.${name})));
    in
    {
      overlays = perPackageOverlays // {
        default = overlay;
        namespaced = namespacedOverlay;
      };

      # Not under `overlays', because it is not an overlay for `pkgs': it is an
      # overlay for the Emacs package scope.  Apply it with
      # `pkgs.emacsPackages.overrideScope nix-jointhefreeworld.emacsOverlay'.
      emacsOverlay = emacs.overlays.default;

      packages = forAllSystems packagesFor;

      # `nix flake check' builds the whole set and runs every Emacs test suite;
      # that is what CI runs.
      checks = forAllSystems checksFor;

      apps = forAllSystems appsFor;
    };
}
