# Splitter for iOS

A native SwiftUI speedrun timer for iPhone and iPad, modelled on
[Splitter](https://github.com/MichaelJBerk/Splitter) for macOS and built on the same engine,
[livesplit-core](https://github.com/LiveSplit/livesplit-core). It builds on Linux with
[xtool](https://github.com/xtool-org/xtool); no Mac or Xcode app is needed.

## Features

- Imports every format Splitter for Mac opens:
  - `.split` bundles (Splitter 4+, plus the older `runInfo.json` format)
  - LiveSplit `.lss`
  - Splits.io `.json`
  - GreenSplit `.gss`, including attempt history, golds, custom comparisons and subsplit groups
    (only the main route is imported, not alternative branches)
  - everything else livesplit-core parses (WSplit, Llanfair, Time Split Tracker, …)
- The default LiveSplit layout (title, splits, timer, previous segment) plus current pace, sum of
  best and possible time save, rendered natively with livesplit-core's ahead/behind/gold colours.
- A large Start/Split button with haptics. Undo, Skip, Pause/Resume and Reset (save or discard
  times). Optional "Tap Splits to Split" (timer menu) turns the whole splits area into the split
  button.
- Hardware keyboard / Bluetooth remote shortcuts: Space split, Delete undo, → skip, P pause,
  R reset.
- Landscape layout on iPhone: splits on the left, controls in a column on the right.
- Live Activity: the running timer and current split on the Lock Screen and in the Dynamic Island.
- The library shows each run's personal best, split and attempt counts and game icon, most
  recently played first.
- Comparison switching (PB, Best Segments, Average, …) and Real/Game time.
- A splits editor for game, category, attempts, offset, icon, segment names, PB split times and
  best segments. Game icons can come from speedrun.com (searched by game name, using the game's
  cover art) or from Photos; either way they're scaled to 256 px. speedrun.com's bot protection
  sometimes refuses the download; the app then offers to retry or open the game's page. You can add, delete and reorder segments.
- New runs from scratch. Delete, duplicate and share as `.lss`.
- Runs autosave as `.lss` in `Documents/Splits`, which shows up in the Files app.
- The screen stays awake during an attempt.
- Reopens the splits you had open when the app was last closed.
- Accessibility, following Apple's Human Interface Guidelines:
  - split colors meet 4.5:1 contrast (7:1 with Increase Contrast), with a color-blind-friendly
    blue/orange option (timer menu → Split Colors)
  - gold segments are marked with a star, not just a color
  - VoiceOver reads what each color means ("behind, losing time")
  - the timer and splits scale with Dynamic Type; splits switch to two lines at the largest sizes
  - Reduce Motion is respected

## Layout

```
Package.swift            SwiftPM manifest (library products: the app and the widget extension)
xtool.yml                bundle ID, Info.plist, icon, extensions
Info.plist               document types (.split / .lss / .json), file sharing, Live Activities
Extensions/              Info.plist of the widget extension
Sources/CLiveSplitCore   livesplit-core C header (generated)
Sources/LiveSplitCore    livesplit-core Swift bindings (generated, unmodified)
Sources/SplitterCore     timer session, layout-state model, file import, run editor, library
Sources/SplitterApp      SwiftUI app
Sources/SplitterActivity Live Activity data shared by the app and the extension
Sources/SplitterWidgets  widget extension drawing the Live Activity
Tests/SplitterCoreTests  core tests (run on Linux)
Vendor/livesplit-core    prebuilt static libs: ios-arm64 (app), linux-x86_64 (tests)
scripts/build-livesplit-core.sh   rebuilds the vendored libs + bindings
```

## Building (Linux)

Prerequisites, already set up on this machine:
- Swift 6.4 via swiftly
- xtool on `PATH`
- the Darwin SDK built from Xcode 27.1 (`xtool sdk status`)
- Rust with the `aarch64-apple-ios` target (only needed to rebuild livesplit-core)

```bash
swift test                          # core tests on Linux
xtool dev build                     # debug .app   -> xtool/Splitter.app
xtool dev build -c release --ipa    # unsigned IPA -> xtool/Splitter.ipa
```

### Building the installer with a workflow (act)

`.github/workflows/build-ipa.yml` is a manually triggered (`workflow_dispatch`) workflow. It checks
the toolchain, runs the core tests, builds the IPA, names it after the app version and date, writes
a `.sha256`, and uploads it as an artifact. Run it locally with
[nektos/act](https://github.com/nektos/act) through the wrapper script:

```bash
scripts/build-ipa.sh                                                  # release, tests first
scripts/build-ipa.sh --input configuration=debug                      # debug build
scripts/build-ipa.sh --input run_tests=false                          # skip the Linux tests
scripts/build-ipa.sh --input rebuild_livesplit_core=true              # rebuild the Rust engine first
```

The installer lands in `dist/`, e.g. `dist/Splitter-1.0-release-20261121-0746.ipa`, and the script
verifies its checksum.

The job runs directly on this machine (act's self-hosted mode), not in Docker, because it needs the
Swift toolchain, xtool and the Darwin SDK built from `Xcode.xip`. act won't accept that setting from
the project `.actrc`, so the script passes it on the command line. GitHub's hosted runners don't
have the Darwin SDK, so on GitHub itself this needs a self-hosted runner set up like this machine.

## Running on an iPhone

1. Install usbmuxd: `sudo pacman -S usbmuxd`.
2. Sign in once with `xtool auth login`. A free Apple ID works; apps signed that way expire after
   7 days.
3. Change `bundleID` in `xtool.yml` to something unique to you.
4. Plug the phone in, unlock it and tap **Trust**. Enable **Developer Mode** under
   Settings → Privacy & Security.
5. Run `xtool dev`. It builds, signs, installs and launches the app.
6. On first launch, trust your developer profile under Settings → General → VPN & Device
   Management.

You can also install the unsigned `xtool/Splitter.ipa` with AltStore or SideStore.

## Updating livesplit-core

```bash
scripts/build-livesplit-core.sh            # pinned commit
scripts/build-livesplit-core.sh <git-ref>  # another version
```

The script cross-compiles only the static library, so Apple's linker isn't needed. It then
regenerates `livesplit_core.h` and `LiveSplitCore.swift`.

## Installing with AltStore Classic

Add this source in AltStore (Browse → Sources → +):

```
https://raw.githubusercontent.com/TotorRuns/splitter-ios/main/altstore/source.json
```

Then install **Splitter** from it. AltStore signs the app with your own Apple ID and offers
updates whenever a new version is published.

## Publishing a release

```bash
scripts/build-ipa.sh --input publish=true --input release_notes="What's new in this build"
```

This builds a release IPA and stamps it with a unique build number (`YYYYMMDDhhmm`, UTC). It then
uploads the IPA to a GitHub release tagged `v<version>-<build>`, adds the version to the top of
`altstore/source.json`, pushes that commit, and pulls it back here. Commit your changes first; the
script refuses to publish a dirty tree. Bump `CFBundleShortVersionString` in `Info.plist` for a new
marketing version.

`scripts/update-altstore-source.py` reads the bundle ID, version, build and permissions from the
IPA itself, so the source always matches what AltStore checks at install time
([source format](https://faq.altstore.io/developers/make-a-source)).

## License

MIT; see [LICENSE](LICENSE). livesplit-core is MIT/Apache-2.0; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

This is an independent app inspired by [Splitter](https://github.com/MichaelJBerk/Splitter) for
macOS. It reads Splitter's file formats but contains none of its code or artwork. The original
Splitter repository has no license.
