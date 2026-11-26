# Contributing

## Project rule: changes go through a pull request

- Do not commit directly to `main`. `main` is protected: changes must arrive through a pull request.
- For each change, create a new branch from `main` (for example `feature/short-description` or `fix/short-description`).
- Commit on that branch, push it, and open a pull request into `main`.
- Merge the pull request once the checks pass. After the merge, delete the branch on GitHub and locally.
- Keep commit messages and pull request text free of assistant or tool names, and do not add co-author or generated-by lines.

## Before opening a pull request

- `swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing` passes.
- `./lint.sh` reports no findings.
- `swift build` completes without errors.

## Documentation comments

- Every public declaration has a doc comment. SwiftLint's `missing_docs` rule enforces this.
- Use the block form `/** ... */` for multi-line docs, so Option-click help shows them. Use `///` only for a one-line summary.
- Structure: a one-sentence summary ending with a period, an optional discussion paragraph, then `- Parameters:`, `- Returns:` and `- Throws:` where they apply.
- Do not add `//` comments that only narrate what the code does. Keep a comment only when it records a constraint or a non-obvious reason, and put it in the declaration's doc comment.

## Conventions

The layer rules, the TDD convention, and the known limitations are described in [LIMITATIONS.md](docs/LIMITATIONS.md) and the project's design notes in `docs/`.
