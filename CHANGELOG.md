# Changelog

All notable changes will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The format is loosely based on [Keep a Changelog][keepachangelog], and this
project adheres to [Semantic Versioning][semver].

## [v0.4.0] - 2026-01-23

- Make dump names unique (#11)

## [v0.3.0] - 2026-01-23

- Rename epochs to dumps (#10)
- Update release script (#9)
- Fix changelog generation and test infrastructure (#8)
- Update release script (a5891c2)
- Correctly load helper code in tests (276c149)

## [v0.2.1] - 2026-01-23

- Accumulate data across multiple dumps instead of overwriting (#7)
- Simplify changelog generation in mix bump (#6)
- Add ex_doc for HexDocs generation + cleanups (#5)
- Simplify README, move details to module docs (#4)
- Add mix bump task for automated releases (#3)
- Modernize tooling and CI (#2)
- Add epochs support for data provenance tracking (#1)

## [v0.2.0] - 2026-01-20

- Add ex_doc for HexDocs generation + cleanups (#5)
- Simplify README, move details to module docs (#4)
- Add mix bump task for automated releases (#3)
- Modernize tooling and CI (#2)
- Add epochs support for data provenance tracking (#1)

## [v0.1.4]

### Added

- Various optimisations to samples storage code

## [v0.1.3]

### Added

- Add option to store N samples per query/stacktrace pair, defaults to 5 samples
- Make less calls to :ets

### Changed

- No longer store all samples
- Store all params for each stored sample

## [v0.1.2]

### Added

- Re-purpose .explain function
- More examples in README.md

### Fixed

- Update migration to include index for params table

## [v0.1.1] - 2024-07-10

### Added

- GitHub CI workflow
- Added .tool-versions
- Added logging when dumping ETS table to Ecto repository
- Mention caveat in the readme
- Added few more convenience functions

### Changed

- Update license
- Removed warnings due to all schema modules being in a single file
- Rely on application configuration in more places

## [v0.1.0] - 2024-07-08

- Initial release
