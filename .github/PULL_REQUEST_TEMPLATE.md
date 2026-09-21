## What this changes

<!-- one paragraph: the failure it addresses, or the capability it adds -->

## The test that proves it can fail

<!-- which assertion in test/run.sh drives the new behaviour into its failure state -->

## Checklist

- [ ] every commit is signed off (`git commit -s`)
- [ ] `shellcheck -S style hooks/*.sh test/run.sh install.sh` passes
- [ ] `test/run.sh` passes on macOS and Linux (CI runs both)
- [ ] no path, hostname, product name or memory content from my own estate
- [ ] a changed default carries its measurement in CHANGELOG.md
