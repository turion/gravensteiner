{
  description = "gravensteiner — Bayesian apple cultivar identification";

  inputs = {
    nixpkgs.url       = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url   = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      imports = [ inputs.haskell-flake.flakeModule ];

      perSystem = { self', pkgs, ... }: {
        # haskell-flake auto-discovers every package in cabal.project and provides
        # a devShell with ghc + cabal-install + haskell-language-server.
        haskellProjects.default = {
          # Match the ambient toolchain; monad-bayes 1.3.0.5 is unbroken here.
          basePackages = pkgs.haskell.packages.ghc912;
          devShell.tools = hp: { inherit (hp) fourmolu hlint; };
          # yq-go is a native (non-Haskell) tool, so it goes through mkShellArgs rather
          # than devShell.tools, which only takes packages from the Haskell package set.
          devShell.mkShellArgs.nativeBuildInputs = [ pkgs.yq-go ];
          settings = {
            # sandwich's own test suite fails on ghc912, which would block
            # fsnotify -> ghcid in the devShell. nixpkgs' idiom for this is
            # dontCheck; haskell-flake spells it `check = false`.
            sandwich.check = false;
          };
        };

        # `nix build` / `nix run` target.
        packages.default = self'.packages.gravensteiner;
      };
    };
}
