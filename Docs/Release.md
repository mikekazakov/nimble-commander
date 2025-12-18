# Releasing a new version of Nimble Commander
*This is a checklist of various steps to take to release a new version, after the actual work is done.*

## Step 1: Update dependencies
In `3rd_Party/README.md`, go through each of the dependencies:
  - Check if there is a newer version, if so:
    - Update the `bootstrap.sh` script of that dependency, make sure it downloads and builds the new version.
    - Update the meta information in `3rd_Party/README.md` (version number, release date).
  - Run `3rd_Party/bootstrap.sh` to rebuild all dependencies in topological order.
  - Rebuild NC, run all tests to make sure everything is working correctly.
  - Commit all the changes.

## Step 2: Update `Help.md`
Go through the commits since the last release, and update `Docs/Help.md` accordingly.

## Step 3: Update the localization files
- In Xcode, go through each `Localizable.xcstrings` (filter the project by `localizable`) and XIB strings (filter the project by `(strings)`).
- Make sure that there's a green check mark next to each localization language (currently there's one, huh).
- Commit all the changes. 

## Step 4: Check the version works on the lowest supported macOS version

## Step 5: Check that MAS version builds and works as well
In case Provisioning Profiles or Signing Certificates have expired, renew them first.

## Step 6: Write "What's New"
Update 'WHATS_NEW.md' with the list of changes since the last release.

## Step 7: Make a release build
Use the 'Release Build' workflow in GitHub Actions on the `main` branch. 

## Step 8: Create a GitHub Release
- Releases -> Draft a new release
- Create new tag: `vX.Y.Z` (the new version)
- Target: `main`
- Add changelog, add the release build.

## Step 9: Build a Sparkle manifest
- Check `template.xml` and update if necessary. 
- Write `whats-new-X.Y.Z.html` from the information in `WHATS_NEW.md`.
- Place the release build and run `compose.sh`.

## Step 10: Update nimble-commander-website
- Place the release build into `/downloads/releases/` as `nimble-commander-X.Y.Z(ABCD).dmg` and as `nimble-commander.dmg`.
- Place the new Sparkle manifest into `/downloads/releases/` as `sparkle-nimble-commander.xml`.
- Update the front page.
- Update the `whats-new` page.
- Update other pages if needed.
- Commit, push, done - congratulations - the new version is out!

## Step 11: Release on Mac App Store as well
