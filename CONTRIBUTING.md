# Contributing

## How to contribute from outside the repository

You need a GitHub account and the Swift toolchain (Xcode or the Command Line Tools). The repository is public, but you can't push branches to it, so work from your own fork.

1. **Fork the repository.** On GitHub, open `nisarg96/StatusMonitor` and choose **Fork**.
2. **Clone your fork** and add the original repository as `upstream`:

   ```sh
   git clone https://github.com/<your-user>/StatusMonitor.git
   cd StatusMonitor
   git remote add upstream https://github.com/nisarg96/StatusMonitor.git
   git fetch upstream
   ```

3. **Create a branch from the latest `main`:**

   ```sh
   git checkout -b fix/short-description upstream/main
   ```

4. **Make the change.** Write the failing test first, then the code. Document every new public declaration (see [Documentation comments](#documentation-comments)).
5. **Check the change locally** with the commands in [Before opening a pull request](#before-opening-a-pull-request).
6. **Commit and push to your fork:**

   ```sh
   git push -u origin fix/short-description
   ```

7. **Open a pull request** from your fork's branch into `nisarg96/StatusMonitor`, base `main`. Describe what changed and how you checked it.
8. **Respond to review.** Push more commits to the same branch; the pull request updates automatically. The maintainer merges the pull request and deletes the branch.

Keep your fork's `main` in step with the original by running `git fetch upstream` and `git merge upstream/main` (or rebase) before starting a new branch.

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
