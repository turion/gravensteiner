{
  description = "gravensteiner — Bayesian apple cultivar identification";

  nixConfig = {
    extra-substituters = [ "https://gravensteiner.cachix.org" ];
    extra-trusted-public-keys = [ "gravensteiner.cachix.org-1:0cE5neWb74eOFaogEv+aFtO5um4g3iivRaQmSj9ueeY=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      imports = [ inputs.haskell-flake.flakeModule ];

      perSystem = { self', pkgs, ... }: {
        # haskell-flake auto-discovers every package in cabal.project and provides
        # a devShell with ghc + cabal-install + haskell-language-server.
        haskellProjects.default = {
          # Match the ambient toolchain; monad-bayes 1.3.0.5 is unbroken here.
          basePackages = pkgs.haskell.packages.ghc912;
          devShell.tools = hp: { inherit (hp) fourmolu hlint cabal-gild; };
          # yq-go is a native (non-Haskell) tool, so it goes through mkShellArgs rather
          # than devShell.tools, which only takes packages from the Haskell package set.
          devShell.mkShellArgs.nativeBuildInputs = [ pkgs.yq-go pkgs.actionlint ];
          settings = {
            # sandwich's own test suite fails on ghc912, which would block
            # fsnotify -> ghcid in the devShell. nixpkgs' idiom for this is
            # dontCheck; haskell-flake spells it `check = false`.
            sandwich.check = false;
          };
        };

        # `nix build` / `nix run` target.
        packages.default = self'.packages.gravensteiner;

        # `nix fmt` target; `rhine` and `changeset` both use nixpkgs-fmt.
        formatter = pkgs.nixpkgs-fmt;

        # Lint the workflow files as part of `nix flake check`, so a bad `uses:`,
        # an invalid expression or a `needs:` naming a job that does not exist
        # fails locally instead of on the run it breaks. nixpkgs' actionlint
        # propagates shellcheck and pyflakes, so `run:` scripts are linted too.
        # The files are passed explicitly: actionlint applies the workflow schema
        # to named files even though the store path is not `.github/workflows`.
        checks.actionlint =
          pkgs.runCommand "actionlint" { nativeBuildInputs = [ pkgs.actionlint ]; } ''
            actionlint -no-color ${./.github/workflows}/*.yml
            touch "$out"
          '';

        # ci.yml's `success` job is the one required check, and it can only fail for a job that
        # its `needs:` list names. That list is hand-maintained, so a job added without touching
        # it would be silently ungated — actionlint catches a *misspelt* dependency but not a
        # missing one. Assert instead that every job except `success` itself is in the list.
        checks.workflow-jobs-gated =
          pkgs.runCommand "workflow-jobs-gated" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
            missing=$(yq '
              (.jobs | keys | map(select(. != "success"))) as $all
              | (.jobs.success.needs // []) as $needs
              | ($all - $needs) | .[]
            ' ${./.github/workflows/ci.yml})
            if [ -n "$missing" ]; then
              echo "ci.yml: these jobs are missing from success.needs, so a failure in them" >&2
              echo "would not turn the required check red:" >&2
              printf '  %s\n' $missing >&2
              exit 1
            fi
            touch "$out"
          '';
      };
    };
}
