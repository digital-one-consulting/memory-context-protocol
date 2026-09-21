# Governance

## Stewardship

This project is stewarded by the **Digital One Foundation** (Stichting Digital One Foundation,
in formation, Amsterdam), a non-profit being established as an independent steward of open
standards, evaluation methodologies and transparency infrastructure for artificial intelligence.
The repository is hosted, for now, under the GitHub organisation of Digital One, the company
that initiated the Foundation; it will transfer to the Foundation's own organisation once the
Foundation is constituted. GitHub redirects the old location after a transfer, so links keep
working.

The Foundation's rule for its own board applies here: no single interest holds a majority.

## Roles

- **Maintainers** review and merge, cut releases, and hold the final say on what the protocol
  is. They are listed in [CODEOWNERS](.github/CODEOWNERS).
- **Contributors** are anyone who has had a change merged. Contributions require a
  [Developer Certificate of Origin](https://developercertificate.org/) sign-off on every commit
  (`git commit -s`); no contributor licence agreement is required.

## Decisions

Changes to the **specification** (`spec/`) are proposals first: open an issue with the
`proposal` template stating the failure the change addresses, with the failing input if there
is one. A specification change ships with the hook or template change that implements it and
the test that proves the new behaviour can fail.

Changes to **defaults** (the four budget thresholds) need a measurement: the line that was
crossed, on what, with the date. The thresholds are scars, and a scar has a story.

## Releases

Semantic versioning. A release is a tag `vX.Y.Z` on `main` with a CHANGELOG entry. Patch:
fixes and portability. Minor: new hooks, commands or budgets, backwards compatible with an
installed copy. Major: a change to the file format or the index rules that an installed
project would have to migrate.

## Scope, and the split-out rule

This repository holds the first layer only: the memory beneath one project's agent sessions.
A shared memory across repositories and an organisation is a different artefact with its own
paper series and belongs in its own repository. A tool that outgrows this one — its own users,
its own release cadence — is split out with `git subtree split`, history intact.

## Licences

Code is licensed under Apache-2.0 ([LICENSE](LICENSE)). The specification text under `spec/`
and the templates are additionally licensed under CC BY 4.0 ([LICENSE-docs](LICENSE-docs)), to
match the papers. See [NOTICE](NOTICE).
