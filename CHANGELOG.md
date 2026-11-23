# Changelog

All notable changes will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Clustering. On connected nodes every node collects and one node, chosen
  through `:global`, writes to SQLite. Nothing to configure.
- `:flush_interval` configuration.

### Changed

- Collected data is written to SQLite every 60 seconds and on shutdown, not
  only when `dump2sqlite/1` is called. Set `flush_interval: false` to keep
  writing by hand.
- `dump2sqlite/1` flushes every connected node, empties ETS and adds to the
  stored counters instead of overwriting them. It returns `:ok` or
  `{:error, failures}`. `ets_stats/0` reports what was collected since the
  last flush.
- SQLite assigns sample ids, and `samples_to_keep` applies to what is stored,
  across nodes and restarts.
- Dumps are named after the node instead of `"1"`.
- Requires `ecto_sqlite3` 0.26 or newer, which brings Ecto 3.14.

### Upgrading

- List the SQLite repo before `EctoQueryExplorer` in your supervision tree,
  so the last flush on shutdown has a repo to write to.
- Counters stored by earlier versions were overwritten on each dump rather
  than added, so start from a new SQLite file if you need them exact.
- On a network volume, set `journal_mode: :delete` on the SQLite repo.
- While pods on an older version are still running, do not call
  `dump2sqlite/1` on them: it overwrites the counters.

### Removed

- The `mix bump` task, which was only ever meant for releasing this package.

## [v0.4.1] - 2026-01-23

- No changes

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
