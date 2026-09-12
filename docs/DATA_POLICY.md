# Data and publication policy

This repository shares research methods while the underlying empirical data and findings remain outside the repository.

## Included

- Newly organized source code for the computational workflow.
- Synthetic input generation, tests, and methods documentation.
- Automated validation with generated examples.

## Withheld

- Raw and processed research data, species names, lookup keys, and sample metadata.
- Empirical tree topology, branch lengths, trait distributions, and statistical findings.
- Manuscripts, supplementary research results, original figures, presentations, and saved analysis sessions.
- Personal names, contact details, student identifiers, institutional paths, and private audit records.

Replacing species names on an empirical tree would still reveal its structure. Therefore this workflow generates a new tree and new traits without reading the original research files. There is no anonymization key and no relationship between `Taxon_` identifiers and actual species.

## Release controls

`release-files.txt` is an explicit publication allowlist. The release checker rejects unexpected tracked files, common data formats, private filesystem paths, email addresses, and common credential patterns. Generated outputs belong in ignored `artifacts/`; they are not uploaded by CI.

Before each release, review the staged diff and commit metadata as well as the allowlist. Use a non-personal commit identity and a GitHub no-reply address. A GitHub repository is still associated with the publishing account; repository controls cannot hide information already displayed by that account.

Automated checks are a backstop, not proof that arbitrary new content is safe. Do not add a file to the allowlist simply to make a check pass. Review its contents and provenance first. Keep any private-to-public comparison records outside this repository.

## Working with empirical data

Adapt the analysis functions in a separate private workspace. Do not place empirical inputs in this checkout, even in an ignored directory. A gitignore rule does not remove a file from an earlier commit and can be overridden by force-adding it.

The public entry point deliberately runs only synthetic examples. Any future empirical release requires a separate review of data rights, disclosure, and publication scope.
