# emacs.nix

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

# The Emacs packages of the set.  Each of them is a single .el file whose
# repository has no Nix expression of its own -- there is no build system to
# call, and packaging an elisp library is the same fixed shape every time -- so
# the expressions live here, next to the flake that hands them out.
#
# `melpaBuild' is the builder MELPA itself uses: it reads the headers of the
# file, writes the -pkg.el and the autoloads, and byte-compiles.  That is what
# makes `(require 'maak)' and the autoloaded commands work for someone who got
# the package through `withPackages'.

{ lib
, emacsPackages
, srcs
}:

let
  # The version lives in the package's own header, where Emacs reads it, so a
  # release stays one edit in one file and the expression cannot fall behind.
  versionOf = file:
    let
      lines = builtins.filter
        (line: lib.hasPrefix ";; Version:" line)
        (lib.splitString "\n" (builtins.readFile file));
    in
    if lines == [ ] then
      throw ''
        ${file} has no `;; Version:' header, which is where emacs.nix reads the
        version from.  Put it back, or set the version by hand here.
      ''
    else
      lib.trim (lib.removePrefix ";; Version:" (builtins.head lines));

  build = { pname, file, src, description, license, homepage }:
    emacsPackages.melpaBuild {
      inherit pname src;
      version = versionOf "${src}/${file}";

      # The repositories carry their tests next to the package, and their
      # COPYING and README as well; a package is the .el files and nothing else.
      files = "(\"*.el\")";

      meta = {
        inherit description homepage license;
        maintainers = [ lib.maintainers.jjba23 ];
      };
    };
in
{
  maak = build {
    pname = "maak";
    file = "maak.el";
    src = srcs.maak;
    description = "Maak integration for Emacs";
    license = lib.licenses.gpl3Plus;
    homepage = "https://codeberg.org/jjba23/maak.el";
  };

  veritas = build {
    pname = "veritas";
    file = "veritas.el";
    src = srcs.veritas;
    description = "Tight Emacs integration for the Veritas test framework";
    license = lib.licenses.lgpl3Plus;
    homepage = "https://codeberg.org/jjba23/veritas.el";
  };

  modusregel = build {
    pname = "modusregel";
    file = "modusregel.el";
    src = srcs.modusregel;
    description = "Mode line customizations";
    license = lib.licenses.gpl3Plus;
    homepage = "https://codeberg.org/jjba23/modusregel";
  };

  tekengrootte = build {
    pname = "tekengrootte";
    file = "tekengrootte.el";
    src = srcs.tekengrootte;
    description = "Proportionally scaled face sizes";
    license = lib.licenses.gpl3Plus;
    homepage = "https://codeberg.org/jjba23/tekengrootte.el";
  };

  welkomscherm = build {
    pname = "welkomscherm";
    file = "welkomscherm.el";
    src = srcs.welkomscherm;
    description = "Simple welcome screen / dashboard";
    license = lib.licenses.gpl3Plus;
    homepage = "https://codeberg.org/jjba23/welkomscherm.el";
  };
}
