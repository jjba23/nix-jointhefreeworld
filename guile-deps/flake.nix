# deps — the Guile dependencies nixpkgs has no package for yet

# Copyright © Josep Bigorra <jjbigorra@gmail.com>

# nix-jointhefreeworld is free software, released under the MIT license: you
# may use, copy, modify, merge, publish, distribute, sublicense and sell it,
# provided that the copyright notice and this permission notice are included in
# all copies or substantial portions of it; see LICENSE.

# nix-jointhefreeworld is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  In no event shall the authors or copyright
# holders be liable for any claim, damages or other liability arising from it.

# A flake of its own, for two reasons.  Each dependency is pinned by this
# lock rather than the set's, so updating one does not touch the other; and it
# can be consumed on its own, which is what keeps the Guile half from being
# something an Emacs user has to fetch.  The set follows this flake, so its
# packages build against the set's nixpkgs rather than this one's.

{
  description = "Guile libraries nixpkgs has no package for yet, on their own";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # One branch of the fork per dependency, read at the path nixpkgs would keep
    # the expression at.  Each input goes away with its entry in `sources'
    # below, once the branch is merged and nixos-unstable has the package.
    guile-uuid-src = { url = "github:jjba23/nixpkgs/guile-uuid-init"; flake = false; };
    guile-dbi-src = { url = "github:jjba23/nixpkgs/guile-dbi-init"; flake = false; };
    guile-dbd-sqlite3-src = { url = "github:jjba23/nixpkgs/guile-dbd-sqlite3-init"; flake = false; };
    guile-dbd-mysql-src = { url = "github:jjba23/nixpkgs/guile-dbd-mysql-init"; flake = false; };
    guile-dbd-postgresql-src = { url = "github:jjba23/nixpkgs/guile-dbd-postgresql-init"; flake = false; };
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

      sources = {
        guile-uuid = { repo = "guile-uuid-src"; expr = "pkgs/by-name/gu/guile-uuid/package.nix"; };
        guile-dbi = { repo = "guile-dbi-src"; expr = "pkgs/by-name/gu/guile-dbi/package.nix"; };
        guile-dbd-sqlite3 = { repo = "guile-dbd-sqlite3-src"; expr = "pkgs/by-name/gu/guile-dbd-sqlite3/package.nix"; };
        guile-dbd-mysql = { repo = "guile-dbd-mysql-src"; expr = "pkgs/by-name/gu/guile-dbd-mysql/package.nix"; };
        guile-dbd-postgresql = { repo = "guile-dbd-postgresql-src"; expr = "pkgs/by-name/gu/guile-dbd-postgresql/package.nix"; };
      };

      # `final.callPackage', so that the drivers build against the same pkgs
      # as whatever is asking for them: guile-dbd-sqlite3 needs guile-dbi, and
      # it has to be *this* guile-dbi, which nixpkgs does not have at all.
      overlay = final: prev:
        lib.mapAttrs
          (_: source: final.callPackage "${inputs.${source.repo}}/${source.expr}" { })
          sources;

      packagesFor = system:
        let pkgs = nixpkgs.legacyPackages.${system}.extend overlay;
        in lib.mapAttrs (name: _: pkgs.${name}) sources;
    in
    {
      # One overlay per dependency, for a consumer that wants guile-dbi and not
      # the drivers.  Each builds against a pkgs extended with the whole set, so
      # that guile-dbd-sqlite3 still finds this guile-dbi even when it is the
      # only name being installed, and then defines just its own name.
      overlays =
        (lib.mapAttrs
          (name: _: (final: prev:
            let pkgs = final.extend overlay;
            in { ${name} = pkgs.${name}; }))
          sources)
        // {
          default = overlay;
        };

      packages = forAllSystems packagesFor;

      checks = forAllSystems (system: self.packages.${system});
    };
}
