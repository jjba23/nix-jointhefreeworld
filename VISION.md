# Vision

`nix-jointhefreeworld` is one flake carrying twenty-seven packages: ten Guile
programs, seven Guile libraries, five Emacs packages, and the five Guile
dependencies nixpkgs has no package for. Its direction is to be the smallest
possible amount of packaging that makes a set of independent repositories
installable together — a set that owns *pins* and never owns *build recipes* —
and then to close the three gaps that currently keep it from feeling like a real
package source: it is slow to install, it cannot be developed in, and its claim
that `nix flake check` verifies the set is true of the Emacs half only.

## Where nix-jointhefreeworld is today

Three flakes, each with its own lock. The root `flake.nix` declares sixteen
`flake = false` inputs — one per Guile project, pinned either to a tag or to a
branch — and follows two halves: `guile-deps/` (the five nixpkgs branches) and
`emacs/` (the five elisp repositories). `inputs.nixpkgs.follows` keeps all three
on one nixpkgs, and `?dir=emacs` lets an Emacs configuration fetch five small
repositories and never the Guile side. Three systems: `x86_64-linux`,
`aarch64-linux`, `aarch64-darwin`. `x86_64-darwin` is absent on purpose, because
nixpkgs 26.11 dropped it and listing it would break evaluation for every
consumer.

The architecture is one idea applied three times: **the set says which commit to
take, and the project says how to build itself.** Every package is
`final.callPackage` over the expression in its own repository — `default.nix` or
`package.nix` — so this repository never restates a build, and the two cannot
drift. That is also why the attribute names are nixpkgs' own (`guile-veritas`,
`maak`), which lets `overlays.default` *replace* an older nixpkgs copy in place
rather than add a second one under a different name.

Four overlay outputs carry it: `overlays.default` puts every name into `pkgs`;
`overlays.namespaced` puts them under `pkgs.jointhefreeworld` and shadows nothing;
each name has a per-package overlay built against the whole set, so
`overlays.araneola` still finds this set's `guile-scriba`; and `emacsOverlay` is an
overlay for the *Emacs package scope* rather than for `pkgs`, applied with
`overrideScope`, because that is where an elisp package actually lives. `packages`
keeps every attribute lazy, so a project that breaks its own expression takes down
itself and nothing else; `checks` forces the set, and filters by each derivation's
`meta.availableOn` so a Wayland dock is left out on Darwin without a list of names.

`maak.scm` is the release tooling. `check-updates` reads `flake.lock` by handing a
`builtins.fromJSON` expression to `nix-instantiate`, then asks each repository what
it has now with one `git ls-remote` per pin — retried three times, because a check
that cries wolf on one lost packet is a check nobody trusts. Tags are compared the
way `sort -V` compares them, so `v0.9.10` follows `v0.9.9`. `update` rewrites a tag
in the flake that declares it, moves a branch with `nix flake update`, and relocks
from the halves up to the set. `nixpkgs` is reported separately and never moved,
since moving it is a decision about every package at once. Two pins are held with
their reasons written down, and a hold whose reason has stopped being true is
reported as stale rather than kept quiet.

## The vision

1. **Installing a package is a download, not a compile.** There is no binary cache
   today, so every fresh install compiles Guile bytecode and every Emacs suite
   re-runs on the user's machine. A signed cache published from CI would make the
   set feel like a distribution instead of a build.
2. **The set can be developed in, not only installed from.** There is no
   `devShells` output and no `formatter`, so `nix develop` and `nix fmt` do not
   work in the repository that packages twenty-seven projects. Both are outputs
   this flake should have had from the start.
3. **`nix flake check` means every suite of every project.** Today it builds the
   whole set and runs the five Emacs ERT suites, explicitly, from source. The
   Guile projects' own Veritas suites run only if their individual expressions run
   them — there is no `suites` table for the Guile half, and a green check
   therefore proves less than the README implies.
4. **The forks are a queue, not a dependency.** The five `guile-deps` entries let
   a package be installed before nixpkgs has it, and each is meant to disappear
   when its branch merges. The set should know which are still needed and say so,
   because a staging area nobody audits becomes a fork nobody maintains.
5. **One lock is the release, and it is verifiable.** A consumer pins a revision of
   `flake.lock` and gets a set known to build together — and the artefacts that
   lock produces should be addressable, so "known to build" is checked rather than
   believed.

## Features that are in scope and not built yet

- **A binary cache.** The largest user-visible change available: publish every
  package's closure per system to a substituter and document the
  `nix.settings.substituters` lines. The hard part is not the push; it is trust
  and staleness — a cache serving a closure for a lock nobody is on is worse than
  no cache, so CI must push on the commit the lock names.
- **`devShells` and `formatter`.** A development shell, and `nixfmt` as the
  `formatter` so `nix fmt` works and the check can fail on an unformatted flake.
  The hard part is nothing; it is here because it is missing and every consumer
  notices within a minute.
- **A `suites` table for the Guile half.** The Emacs flake already builds a
  `runCommand` per ERT suite, copying the tree out of the read-only store, setting
  `HOME=$PWD` and running it from source. The same shape applied to the Veritas
  suites would make `nix flake check` run what the README claims. The hard part is
  that each project's suite needs its own environment — a `migrations` directory, a
  SQLite file, a `runtime-path` — so this is a table of invocations.
- **A licence check.** The README has a licence column for twenty-seven packages
  and nothing verifies it. A `checks` entry asserting that every package declares
  `meta.license`, that none is unfree, and that each matches the table, would keep
  a claim that currently rests on care.
- **A CI matrix.** One `ubuntu-latest` job per flake today, so `aarch64-linux` is
  never built and `aarch64-darwin` never tested, though both are in `systems`. The
  hard part is cost: native `aarch64-linux` runners are not free, and
  cross-compilation proves expressions evaluate without proving suites run.

## New features that would be worth having

- **A `lib` output**, so a consumer with their own nixpkgs can instantiate the set
  without copying the overlay plumbing: `nix-jointhefreeworld.lib.packagesFor pkgs`,
  the same function `packages` calls internally.
- **A `nix flake check` that reports what it skipped**, since a Darwin run silently
  omits the Wayland programs. Speculative: `checks` is a set, and a set cannot say
  what is not in it without a wrapper.
- **A `sbom` per release**, generated from the closure, so "which of these
  twenty-seven projects is in my system, at which revision" is answerable from an
  artefact rather than from a lock file. Speculative, and only worth it if a
  consumer asks.
- **A per-package documentation index** — the manual page or `--help` for the ten
  programs, the module list for the seven libraries — generated from the built
  derivations rather than written by hand.

## Contributions that would move the needle

1. **`devShells` and `formatter`.** Twenty lines each, no risk, and they turn
   `nix develop` from an error into the obvious way to work on the set. The
   `forAllSystems` helper the flake already has is the whole scaffold.
2. **A binary cache from CI.** The largest lifetime saving available to every
   future user, and the work is a CI step plus a paragraph about trust. It is what
   makes a Guile package in Nix usable on a first install rather than after a
   five-minute build.
3. **The Guile `suites` table.** It makes an existing claim true, and the Emacs
   flake's `testChecksFor` is the pattern to copy — including the `HOME=$PWD`
   detail that catches everyone once.
4. **The licence check.** Small, deterministic, and it protects a README table that
   twenty-seven packages depend on being right.
5. **`maak check-upstream`.** It reuses the machinery `maak.scm` already has —
   `ls-remote`, version comparison, the report shape — to shrink the fork, the only
   part of this repository meant to go away.
6. **A CI matrix for `aarch64-linux`**, the one platform claim (`systems` lists it)
   that nothing currently verifies — and a README pass adding a `nix run` line per
   program, generated from `apps`, so the table and the flake cannot disagree.

## Compared to related projects

| Project | What it is | Where nix-jointhefreeworld differs |
| --- | --- | --- |
| nixpkgs | The monorepo every Nix user already has: ~100,000 packages, one repository, one giant set of expressions. | This set owns pins, not recipes — every build lives in the project's own repository — so it can never carry a stale copy of how something is built. nixpkgs' breadth is what this deliberately does not compete with: five of its entries exist here only because nixpkgs has none yet. |
| NUR (Nix User Repository) | One flake aggregating community repositories, addressed as `nur.repos.<owner>.<package>`, with `flake = false` inputs per repository. | The closest structural relative, and the same `flake = false` idiom. NUR pools *many people's* packages behind one namespaced attribute; this set is one author's, and bets on overlays — three of them, including a per-package one — rather than on a single `repos` namespace, so its packages can replace nixpkgs copies in place. |
| flake-utils | The small library behind `eachSystem`, `eachDefaultSystem` and `mkApp`, used by most flakes that support several systems. | This flake's `forAllSystems` is the four lines `flake-utils` would give it, so the dependency is not worth taking for one function — and the flake's `apps` and `checks` need `meta.mainProgram` and `meta.availableOn` handling that a generic helper does not do. |
| flake-parts | A module system for flake outputs, so a large flake is described as composable parts with options rather than as nested attribute sets. | `flake-parts` pays off when several people contribute to one flake's outputs. Three flakes of ~150 lines each do not need a module system, and the split into `emacs/` and `guile-deps/` already gives the composability that matters here: a consumer fetches only the half they want. |
| nix-update | The standard tool for bumping a package's `version` and hashes: `nix-update --flake attr`, with `--version`, `--rev` and `--branch` modes. | `maak check-updates`/`update` is an in-house version of the same job, narrowed to what a *set of separately versioned repositories* needs: one report over every pin, tag comparison the way `sort -V` does it, branch pins moved by `nix flake update`, halves relocked inside out, and held pins with reasons. `nix-update` would still be the right tool for a hash-bearing expression inside one project. |
| Cachix, nix-community's cache | Hosted binary caches and the tooling to push to them, so a flake's closure is downloaded rather than built. | This set has no cache at all, which is its largest functional gap. Adding one is the first contribution below the two small ones, and it is the difference between a package source and a source tree. |
| devenv, numtide/devshell | Frameworks for declaring development shells with services, processes and per-shell packages. | Both are heavier than what this needs: a `devShells` output with the project's dependencies in `nativeBuildInputs` is `mkShell`, and taking a framework to get it would be the first heavyweight dependency in a repository whose only dependency is nixpkgs. |

What the others do that this could still add: `nix-update`'s discipline of
verifying that a new revision builds before it is recorded, which `maak update`
leaves to `nix flake check` afterwards and a release should not; Cachix's
substitution, without which every consumer pays for the whole set; `flake-utils`'s
`eachSystem` brevity, a convenience rather than a capability; and `flake-parts`'
habit of exposing every output as a named, documented part, which would make `nix
flake show` a better answer than the README table.

Where it is ahead and should stay ahead: **the expression lives in the project's own
repository**, so packaging cannot drift from the thing packaged and one file serves
both the Guile user and the Nix user; **attribute names are nixpkgs' own**, so the
overlay replaces rather than shadows and `pkgs.maak` means one thing; **three
flakes with one nixpkgs** (`follows`), so a consumer takes the half they need and
still gets a single pin; **per-package overlays** built against the whole set, so
installing one name does not break its siblings; **lazy package attributes**, so
one project's broken expression is one project's failure; and **a release task that
treats an unpackagable release as a documented hold** rather than a failed run.

## In the long run

**A set that owns pins and nothing else stays small.** The bet is on the
`flake = false` + `callPackage` arrangement: twenty-seven packages with no build
recipe here at all, and so no way for a recipe here to be wrong about a project
over there. Anything that would put a derivation in this tree — a patch, an
override, a `postInstall` — is a small defeat of that idea, paid for by fixing the
project's own expression.

**The forks are meant to shrink to nothing.** `guile-deps` is a staging area for
five packages nixpkgs lacks, each read from a branch a pull request can merge, and
each entry designed to be deleted. A package set whose fork grows is a set that
has stopped contributing upstream; the health metric worth watching is not the
package count but the number of `guile-deps` entries, and it should trend to zero.

**Emacs users should never pay for Guile.** The three-flake split is a bet that
the two audiences are genuinely different — an Emacs configuration wants five
small repositories and no compiler — and that the cost of maintaining one extra
lock is far below the cost of making every elisp user fetch a Scheme toolchain.
Splitting further, if a third audience appears, is the same move again.

## Getting involved

`nix flake check` in each of the three directories is the whole gate, and what CI
runs. `maak check-updates` opens a release honestly and `maak update` moves what it
finds; `nix run .#maak -- --list` shows both from a checkout. Packaging bugs,
missing platforms and README corrections belong here; a bug in a program belongs in
that program's repository.

*This document describes intent, not commitments: it names directions the project
would like to take, and no item in it is promised for any release.*
