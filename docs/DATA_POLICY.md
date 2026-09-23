# Data and publication policy

This repository shares research methods while the underlying empirical data and findings remain outside the repository.

## Included

- Newly organized source code for the computational workflow.
- Synthetic input generation, tests, and methods documentation.
- Automated validation with generated examples.
- A static research website, five reviewed synthetic SVG illustrations, and two independently simulated PNG methods illustrations documented in the [figure notes](workflow-outputs.md).

## Withheld

- Raw and processed research data, species names, lookup keys, and sample metadata.
- Empirical tree topology, branch lengths, trait distributions, and statistical findings.
- Manuscripts, supplementary research results, original figures, presentations, and saved analysis sessions.
- Personal names, contact details, student identifiers, institutional paths, and private audit records.

Replacing species names on an empirical tree would still reveal its structure. Therefore this workflow generates a new tree and new traits without reading the original research files. There is no anonymization key and no relationship between `Taxon_` identifiers and actual species.

## Release controls

`release-files.txt` is an explicit publication allowlist. The release checker rejects unexpected tracked files, common data formats, private filesystem paths, email addresses, and common credential patterns. Generated run outputs belong in ignored `artifacts/`; they are not uploaded by CI. Published illustrations are restricted to five reviewed synthetic SVGs, reproduced with `scripts/export_gallery.R`, and `method_tree.png` / `method_matrix.png`, reproduced with `scripts/export_methods.R`, under `docs/figures/`.

The gallery SVGs must contain synthetic provenance text and self-contained static drawing elements. Active content, external references, and embedded images are rejected. Review the visible drawing as well as its source: text converted to vector outlines cannot be checked reliably by searching for names alone.

The two PNG files must use their reviewed dimensions and RGB encoding. The checker validates their signatures, chunk checksums and ordering, bounded decompression, and exact image payload lengths. Text, EXIF, animation and other unapproved chunks, oversized files, and trailing content are rejected. Their visible simulated labels and provenance are reviewed separately: valid image structure cannot establish whether pixels disclose research. Before publication, compare the released images with fresh outputs from the reviewed independent generator.

The GitHub Pages site serves only the reviewed `docs/` folder. Its local JavaScript switches between figure views; it does not fetch data, collect visitor inputs, or use browser storage. The website contains no analytics, forms, or external font/image services.

Before each release, review the staged diff and commit metadata as well as the allowlist. Use a non-personal commit identity and a GitHub no-reply address. A GitHub repository is still associated with the publishing account; repository controls cannot hide information already displayed by that account.

Automated checks are a backstop, not proof that arbitrary new content is safe. Do not add a file to the allowlist simply to make a check pass. Review its contents and provenance first. Keep any private-to-public comparison records outside this repository.

## Working with empirical data

Adapt the analysis functions in a separate private workspace. Do not place empirical inputs in this checkout, even in an ignored directory. A gitignore rule does not remove a file from an earlier commit and can be overridden by force-adding it.

The public entry point deliberately runs only synthetic examples. Any future empirical release requires a separate review of data rights, disclosure, and publication scope.
