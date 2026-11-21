# Third-party notices

## livesplit-core

Splitter for iOS includes [livesplit-core](https://github.com/LiveSplit/livesplit-core)
(commit `428d1ea3281cab6a339e860a7068aa3cacb9d7ed`), dual-licensed under MIT or Apache-2.0:

- `Vendor/livesplit-core/*/liblivesplit_core.a`: compiled library
- `Sources/CLiveSplitCore/include/livesplit_core.h` and `Sources/LiveSplitCore/LiveSplitCore.swift`:
  generated bindings
- `Tests/SplitterCoreTests/Fixtures/sample.lss`: test file from livesplit-core's test suite

The license texts are in [Vendor/livesplit-core/LICENSE-MIT](Vendor/livesplit-core/LICENSE-MIT) and
[Vendor/livesplit-core/LICENSE-APACHE](Vendor/livesplit-core/LICENSE-APACHE).
The compiled library also contains livesplit-core's Rust dependencies, under their own permissive
licenses (MIT, Apache-2.0, Zlib, BSD and similar).

## Splitter for macOS

This app is an independent reimplementation inspired by
[Splitter](https://github.com/MichaelJBerk/Splitter) by Michael Berk. It reads Splitter's file
formats but contains none of its code or artwork.
