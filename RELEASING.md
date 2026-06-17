# Releasing ShuttleX

Maintainer notes for cutting a release and the automation around it.

## TL;DR

1. Make the change; keep `swift test` green.
2. Bump the version in `Resources/Info.plist` (`CFBundleShortVersionString` **and** `CFBundleVersion`).
3. Add a `## [X.Y.Z] - YYYY-MM-DD` section (and a compare link) to `CHANGELOG.md`.
4. Update `README.md` / the [Wiki](https://github.com/DasDuo/ShuttleX/wiki) if behavior/usage changed.
5. Commit, push `main`, then:
   ```sh
   git tag vX.Y.Z && git push origin vX.Y.Z
   ```

The **Release** workflow (`.github/workflows/release.yml`) does the rest.

## What the workflow automates (on tag push)

1. **Guard** — fails fast unless `Info.plist` version equals the tag **and** `CHANGELOG.md` has a `## [X.Y.Z]` section.
2. **Build** — arm64 app, `ShuttleX-X.Y.Z-arm64.zip` (`build.sh`) and `…-arm64.dmg` (`make-dmg.sh`).
3. **Release** — creates the GitHub Release, using the matching CHANGELOG section as the notes.
4. **Homebrew cask** — bumps `version` + `sha256` in `DasDuo/homebrew-tap` (`Casks/shuttlex.rb`) and pushes — **only if** the `HOMEBREW_TAP_TOKEN` secret is set (otherwise it skips, and the release still succeeds).

## One-time setup: Homebrew cask automation

The cask is in a **separate repo** (`DasDuo/homebrew-tap`), so the default `GITHUB_TOKEN` can't push to it. Provide a token once:

1. Create a **fine-grained PAT**: GitHub → Settings → Developer settings → Fine-grained tokens → *Generate new token*.
   - **Resource owner:** DasDuo
   - **Repository access:** Only select repositories → `homebrew-tap`
   - **Permissions:** Repository permissions → **Contents: Read and write**
   - Set an expiry you're willing to renew.
2. Add it as a secret in the **ShuttleX** repo: Settings → Secrets and variables → Actions → *New repository secret* → name `HOMEBREW_TAP_TOKEN`, value = the PAT.

That's the only manual step; afterwards every release bumps the cask automatically.

## Manual fallback — bump the cask by hand

If the cask step is skipped (no token) or fails, do it manually:

```sh
VERSION=1.7.1   # the released version
SHA=$(curl -sL "https://github.com/DasDuo/ShuttleX/releases/download/v${VERSION}/ShuttleX-${VERSION}-arm64.dmg" | shasum -a 256 | awk '{print $1}')

git clone https://github.com/DasDuo/homebrew-tap && cd homebrew-tap
sed -i '' -E "s/^  version \".*\"/  version \"${VERSION}\"/" Casks/shuttlex.rb
sed -i '' -E "s/^  sha256 \".*\"/  sha256 \"${SHA}\"/"   Casks/shuttlex.rb

brew audit --cask --online dasduo/tap/shuttlex   # optional sanity check
git commit -am "shuttlex ${VERSION}" && git push
```

## Troubleshooting

- **Workflow fails at "Verify release metadata"** — the tag doesn't match `Info.plist`, or the CHANGELOG has no section for it. Fix the files on `main`, then move the tag:
  ```sh
  git tag -d vX.Y.Z && git push origin :vX.Y.Z   # delete local + remote tag
  git tag vX.Y.Z && git push origin vX.Y.Z        # re-tag the fixed commit
  ```
- **Cask step prints "HOMEBREW_TAP_TOKEN not set"** — expected until the secret exists. Add it (above) or use the manual fallback.
- **Cask push fails with 403** — the PAT expired or lost `Contents: write` on `homebrew-tap`. Recreate it and update the secret.
- **`brew install` reports a checksum mismatch** — the cask `sha256` doesn't match the released DMG. Re-run the manual fallback to recompute it.
- **Need to re-release the same version** — delete the release and tag, then re-tag. The cask step is idempotent (it skips when nothing changed).

## Verify after a release

```sh
gh release view vX.Y.Z --repo DasDuo/ShuttleX
brew update && brew upgrade --cask shuttlex
```
