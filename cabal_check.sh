#! /usr/bin/env bash
# Check every package's cabal file: `cabal check` for the complaints that would block a Hackage
# upload, and `cabal-gild` for formatting. cabal-gild rewrites in place, so the closing
# `git diff --exit-code` is what turns a reformatting into a failure rather than a silent fixup.
#
# CI's `check-cabal-file` job runs this. Locally there is no need to: `jj fix` already applies
# cabal-gild over `glob:**/*.cabal`, so a stack that has been through `jj fix` keeps this green.
set -euo pipefail

# Run from the repo root whatever the caller's directory, so the `*/*.cabal` glob and the final
# `git diff` both mean the same thing every time.
cd "$(dirname "$0")"

shopt -s nullglob
cabalfiles=(*/*.cabal)
if [ "${#cabalfiles[@]}" -eq 0 ]; then
    echo "cabal_check.sh: no */*.cabal found — is this the repo root?" >&2
    exit 1
fi

for cabalfile in "${cabalfiles[@]}"; do
    # A subshell rather than pushd/popd: `cabal check` has to run in the package directory, and
    # the dir-stack builtins would print the stack to stdout on every iteration.
    (
        cd "$(dirname "$cabalfile")"
        cabal check
        cabal-gild --io="$(basename "$cabalfile")"
    )
done

# Scoped to the cabal files on purpose. An unscoped `git diff` passes in CI, where the checkout is
# clean, but locally it fails on any unrelated uncommitted change and blames cabal-gild for it.
if ! git diff --exit-code -- "${cabalfiles[@]}"; then
    echo "cabal_check.sh: cabal-gild reformatted the cabal file(s) diffed above. Run 'jj fix'." >&2
    exit 1
fi
