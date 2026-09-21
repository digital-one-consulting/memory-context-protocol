# Contributing

## Before you start

Read the four papers, or at least the first and the third — they are the reason each piece of
this repository exists, and a change that contradicts a measured finding will be asked for its
measurement: <https://digital1.foundation/articles/the-first-layer/>.

## The rules

1. **Sign off every commit** (`git commit -s`). This adds a `Signed-off-by:` trailer certifying
   the [Developer Certificate of Origin](https://developercertificate.org/). The `dco` workflow
   checks it on every pull request.
2. **A hook change ships with its test.** `test/run.sh` must drive the new behaviour into its
   failure state and see it fire. A check that has never been seen to fail is not a check.
   A hook change also updates the inline copy in `init/claude-context-init.md`: run
   `init/sync-hooks.sh` (the suite diffs them and fails if they drift).
3. **Hooks must never take the session down.** Every hook exits 0 (the Stop hook exits 2 only
   to block, deliberately) and tolerates a missing project directory, a missing git, a missing
   file. `set -e` is not used in hooks for this reason.
4. **Portability is a requirement, not a nicety.** macOS, Linux and git-bash on Windows. GNU
   `stat -c` before BSD `stat -f`; `awk` not `perl`; `shasum`/`sha1sum`/`md5sum`/`cksum` in
   that order. `shellcheck -S style` must pass.
5. **A number in prose is a claim.** A new default or threshold needs the line that was crossed,
   with a date. Don't introduce a figure the CHANGELOG cannot trace.
6. **Nothing from your estate.** Paths, hostnames, product names, memory contents and session
   states from your own projects do not belong in fixtures or examples. Fixtures are built in
   temporary directories at run time; examples are synthetic.

## Running the checks

```sh
shellcheck -S style hooks/*.sh test/run.sh install.sh
test/run.sh
```

## Proposals

Specification changes start as an issue using the `proposal` template: the failure, the failing
input, the change, the test. Small fixes can go straight to a pull request.

## Ports

A port to another harness is welcome as `ports/<harness>/` with its own README, the same file
format, and tests that drive its checks into failure. The spec's file format and index rules
are the contract; hook events and instruction-file names are the harness's.

## Style

Comments explain a constraint the code cannot show — the reason a threshold is where it is,
the replay attack a guard survives — never what the next line does. Match the surrounding
code.
