# emacs — the Emacs packages of Jointhefreeworld, without the Guile side

# Copyright © Josep Bigorra <jjbigorra@gmail.com>

# nix-jointhefreeworld is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# nix-jointhefreeworld is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with nix-jointhefreeworld.  If not, see <https://www.gnu.org/licenses/>.

# A flake of its own so that an Emacs configuration can take the elisp
# packages and nothing else: five small repositories and nixpkgs, without the
# Guile projects or the five nixpkgs branches their dependencies come from.
# The set follows this flake, so a consumer of the whole thing still gets one
# pin for everything.

{
  description = "Jointhefreeworld's Emacs packages, on their own";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    maak-el = { url = "git+https://codeberg.org/jjba23/maak.el"; flake = false; };
    veritas-el = { url = "git+https://codeberg.org/jjba23/veritas.el"; flake = false; };
    modusregel = { url = "git+https://codeberg.org/jjba23/modusregel"; flake = false; };
    tekengrootte-el = { url = "git+https://codeberg.org/jjba23/tekengrootte.el"; flake = false; };
    welkomscherm-el = { url = "git+https://codeberg.org/jjba23/welkomscherm.el"; flake = false; };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = lib.genAttrs systems;

      srcs = {
        maak = inputs.maak-el;
        veritas = inputs.veritas-el;
        modusregel = inputs.modusregel;
        tekengrootte = inputs.tekengrootte-el;
        welkomscherm = inputs.welkomscherm-el;
      };

      # An overlay for the Emacs package scope, not for `pkgs': it is applied
      # with `overrideScope', so it adds five names to `emacsPackages' and
      # leaves everything else alone.  Each package is built by the expression
      # in its own repository, called from that repository's `default.nix' --
      # the same arrangement as the Guile half: this flake says which commit to
      # take, the project says how to build itself.  `melpaBuild' comes from
      # `final', the scope being extended; `lib' is not in that scope, so it is
      # passed in.
      overlay = final: prev:
        lib.mapAttrs
          (name: src: final.callPackage "${src}/default.nix" { inherit lib; })
          srcs;

      scopeFor = system:
        (nixpkgs.legacyPackages.${system}.emacsPackages).overrideScope overlay;

      packagesFor = system:
        let scope = scopeFor system;
        in lib.listToAttrs
          (map (name: lib.nameValuePair "emacs-${name}" scope.${name}) (builtins.attrNames srcs));

      # Every Emacs package brings an ERT suite.  Run it, the way the project's
      # own maak.scm does and from the source tree rather than from the
      # installed copy, so that `nix flake check' tests the elisp and not only
      # that it byte-compiles.
      suites = {
        maak = { src = inputs.maak-el; file = "test/maak-test.el"; };
        veritas = {
          src = inputs.veritas-el;
          file = "test/veritas-test.el";
          # This suite asks whether `guile' exists on PATH and tests one way if
          # it does, the other if it does not; without it three tests fail.  The
          # two end-to-end cases stay skipped either way, since their fixture
          # wants the veritas launcher, which this flake does not install.
          tools = [ "guile" ];
        };
        modusregel = { src = inputs.modusregel; file = "test/modusregel-test.el"; };
        tekengrootte = { src = inputs.tekengrootte-el; file = "test/tekengrootte-tests.el"; };
        welkomscherm = { src = inputs.welkomscherm-el; file = "test/welkomscherm-test.el"; };
      };

      testChecksFor = system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in lib.mapAttrs'
          (name: suite: lib.nameValuePair "emacs-${name}-tests"
            (pkgs.runCommand "emacs-${name}-tests"
              {
                nativeBuildInputs = [ pkgs.emacs ]
                  ++ (map (tool: pkgs.${tool}) (suite.tools or [ ]));
              }
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
    in
    {
      overlays.default = overlay;

      packages = forAllSystems packagesFor;

      # The packages as well as their tests, so that `nix flake check' in this
      # directory is the same statement as it is in the set.
      checks = forAllSystems (system: packagesFor system // testChecksFor system);
    };
}
