# Releases

Every push to `main` runs semantic-release. It reads commit messages since the last release, chooses the next version, and publishes a Git tag and GitHub release with generated notes.

- `fix: correct timer layout` → patch (1.0.1)
- `feat: add daily clock` → minor (1.1.0)
- `feat!: change recording format` or a `BREAKING CHANGE:` footer → major (2.0.0)
- `docs:`, `chore:`, and other non-release commits → no release

Use these messages for commits on main, or for the final squash-merge title. Release tags use `v1.0.0` format. The original 1.0 release is the baseline.

The workflow uses GitHub's built-in token; no additional secret is needed. It publishes source releases, not signed iOS builds or App Store submissions. Xcode's marketing version remains manually managed for app distribution.

Run the Release workflow manually to check for pending release commits. For a local preview, run `npx --yes semantic-release@25.0.9 --dry-run` with GitHub authentication on main.
