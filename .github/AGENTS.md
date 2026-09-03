# CI, formatting and pushing

Read this before pushing, and before touching `.github/`, `flake.nix` or anything about formatting.
It is split out of the repo root's `AGENTS.md`, which every agent loads, because none of it is
needed to write code — only to get code out of this machine cleanly.

`.github/workflows/ci.yml` runs on every push and pull request;
`.github/workflows/update-flake-lock.yml` runs weekly (and on `workflow_dispatch`) to open a pull
request bumping `flake.lock`; `.github/dependabot.yml` opens pull requests for stale GitHub
Actions daily.

## Before you push

- **`jj fix` applies the formatting**, over the whole stack, once. Two caveats on this machine:
  - `fix.tools.fourmolu` is already configured (`fourmolu --stdin-input-file $path` over
    `glob:**/*.hs`) and `fix.tools.cabal-gild` alongside it (over `glob:**/*.cabal`) — see
    `jj config list --include-defaults` — so a plain `jj fix` picks both up with no further setup.
  - **A foreign `hlint` tool is also configured**, applying another project's automatic
    refactorings to every `.hs` file (`fix.tools.hlint.command = ["hlint", "-", "--refactor", "-h",
    "/home/turion/heilmannsoftware/connect/.hlint.yaml"]` over `glob:**/*.hs`) — unrelated to this
    repo and liable to undo deliberate hlint decisions made here. `jj fix` has no `--tool` flag, so
    the only way to scope it to fourmolu is disabling that tool at repo scope:

        jj config set --repo fix.tools.hlint.enabled false

    This writes to a config file *outside* the repository, under a per-clone hash — there is no
    `.jj/repo/config.toml` to check in, so a fresh clone must run the command again. Find the file
    with `jj config path --repo`; do not hard-code the path, since the hash differs per clone.
- **`.nix` files have no `jj fix` route, so run `nix fmt .` by hand** whenever a `flake.nix` edit
  might need it. `check-flake` runs `nix fmt . --accept-flake-config` (`nixpkgs-fmt`, the flake's
  `formatter` output) and fails on drift, so a `flake.nix` edit — the next `check = false` line,
  say — otherwise only turns that required check red once it has been pushed. There is no working
  `jj fix` route today: `nixpkgs-fmt` is not on `PATH`, neither in the ambient shell nor inside
  `nix develop` (`command -v nixpkgs-fmt` fails both ways) — it is built only as the flake's
  `formatter` output, not part of the devShell, so a `fix.tools.nixpkgs-fmt` entry naming it bare
  would just fail to find the binary. Adding it to the devShell would fix that, but is a
  `flake.nix` change. `nix fmt .` is the same command CI runs, so a local pass means the check
  will pass too.
- **`nix flake check` also checks the workflow files**, through two `flake.nix` outputs. A flake
  only sees *tracked* files, so a brand-new workflow is covered by neither until it is snapshotted.
  - `checks.actionlint` — a bad `uses:`, an invalid expression or a `needs:` naming a job that
    does not exist fails locally. nixpkgs' `actionlint` propagates shellcheck and pyflakes, so
    `run:` scripts are linted too.
  - `checks.workflow-jobs-gated` — asserts every `ci.yml` job except `success` itself appears in
    `success`'s `needs:` list. `success` is the one required check and can only fail for a job it
    depends on, so a job added without extending that list would be silently ungated; actionlint
    catches a *misspelt* dependency but not a missing one.
- `jj agent-log` already embeds `-n10`, so passing another `-n`/`--limit` fails with
  `the argument '--limit <LIMIT>' cannot be used multiple times`. Call it bare.

## What the two `ci.yml` halves check

The cabal half (`build-cabal`, over the GHC matrix `generateMatrix` derives from the cabal file's
`tested-with`) verifies the version range the cabal files advertise against compilers other than
the ambient one. The nix half (`check-flake`, `build-flake`) verifies the flake, including the
`nix develop` shell that haskell-flake builds from every dependency's nixpkgs derivation, test
suite included.

Read the direction carefully: when *this repo* adds a `build-depends` entry, the failure mode
documented in the root `AGENTS.md` (a dependency's own test suite failing under haskell-flake,
e.g. `sandwich` or `optics`) is caught **locally first**, by the house build gate, on the very
revision that adds the entry — CI cannot beat that. What CI adds is the other direction:
`update-flake-lock.yml`'s weekly pull request, where nixpkgs moves underneath an *unchanged*
dependency list. Nobody runs `nix flake update` by hand on a schedule, so that failure has no
local gate at all; `build-flake` running on that pull request is the only thing that catches it.

## The `dev` flag

`-Wall` is always on in both packages; `-Werror` sits behind `flag dev`, **off by default** — that
is why `cabal check` passes clean and why either package could go to Hackage without a portability
objection. CI passes `-fdev` on its cabal build and test steps, and so do the house gates in the
root `AGENTS.md`; that is how "`-Werror` on every sealed revision" is actually enforced.

`gravensteiner`'s executable stanza carries three matching downgrades inside its own `if flag(dev)`
block — `-Wno-error=type-defaults`, `-Wno-error=unused-matches`, `-Wno-error=unused-imports` —
because `app/Main.hs` is the superseded precursor described under "Where things stand" in the root
`AGENTS.md` and is not being fixed; without them, `-fdev` would fail on that file's own warnings.
All three go when that file does. `.hlint.yaml` excludes the same file by path, for the same reason.

## How to see a run

After `jj git push`, `gh run list -L 1` (or `gh run watch`) shows the push-triggered `ci.yml` run.
Neither bot pull request stream produces terminal output, and they do not notify alike: Dependabot's
PRs are authored by `dependabot[bot]`, and the owner auto-watches repositories he created, so those
**do** notify him. The weekly `update-flake-lock` PR is authored by his own token,
`GH_TOKEN_FOR_UPDATES`, instead, and GitHub's "your own updates" notifications are off by default —
so **that** stream is the silent one. The token is a user credential rather than the default
`GITHUB_TOKEN`, so its checks still run — the default token would instead have opened the PR with
**no checks box at all** (an absent box, not a red X). `update-flake-lock`'s
`pr-assignees`/`pr-reviewers` inputs are a one-line way to make the silent-PR case surface, if he
wants that; neither is set today. The token is set to **no expiry**; were it ever swapped for an
expiring one, it is consumed only at the PR-creation step, so an expired token would fail the job
there and no PR would open at all, leaving `pr-assignees`/`pr-reviewers` nothing to assign. Find
either stream with `gh pr list`, then check a given one with `gh pr checks <n>`.

Actions are pinned to their **major** tag, so Dependabot's pull requests are the interesting ones
(a new major) rather than a stream of patch bumps. `kleidukos/get-tested` is the one exception,
pinned exactly, because it publishes no `v0` tag.

## The poisoned-eval-cache symptom

Concurrent `nix` invocations on this machine can leave a partial row in the eval cache. The symptom
looks exactly like a broken flake: `nix develop` starts failing with `expected flake output
attribute 'devShells.x86_64-linux.default' to be a derivation or path but found a set`. The fix is
`rm -rf ~/.cache/nix/eval-cache-v5`, confirmed by `nix develop --no-eval-cache -c true` succeeding
— it is a workaround, not a repair, so it can recur. Run `nix` commands one at a time to avoid
triggering it.
