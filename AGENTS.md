# Hacking notes

- **HLS is available** in the devShell and usable, but its diagnostics may be **stale** —
  cross-check against `cabal build -v0 all` before trusting them.
- **Do not run `fourmolu`.** Formatting is handled manually by the maintainer; leave
  whitespace alone even when `fourmolu --mode check` fails.
