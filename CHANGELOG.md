# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

None

## [1.0.2] - 2026-01-02

### Changed

- **Swift 6.2 support**: supports the stable release of Swift 6.2
  - `swift-tools-version`: 6.0 → 6.2
  - `swift-syntax`: 600.0.0 → 602.0.0
  - Unified dependency requirements on `.upToNextMajor`

## [1.0.1] - 2026-01-01

### Changed

- **@Statable macro**: removed the automatic generation of `public init()`
  - To avoid an interaction problem with the `@Observable` macro
  - Users must define `public init() {}` explicitly
  - Makes custom initialization, such as dependency injection, possible

## [1.0.0] - 2025-01-01

### Added

- **@Statable macro**: a declarative state management macro
  - Defines a store class that manages a single asynchronous value
  - Integration with `@MainActor @Observable`
  - Adds operation tracking through the optional `operations` parameter

- **AsyncState<T>**: an exclusive representation of asynchronous state
  - `.idle`: initial state
  - `.loading(previous:)`: loading (can hold on to the previous value)
  - `.loaded(Value)`: load succeeded
  - `.failed(StateError)`: load failed

- **AsyncValue<T>**: an @Observable-conforming wrapper for an asynchronous value
  - Properties such as `value`, `state`, `isLoading`, `hasValue`, `error`
  - State transition methods such as `set(_:)`, `setError(_:)`, `startLoading()`, `reset()`
  - Convenience methods such as `load(_:)`, `loadIfNeeded(_:)`, `reload(_:)`

- **OperationTracker<Op>**: concurrent tracking of multiple operations
  - Operation lifecycle management with `start(_:)`, `complete(_:)`, `fail(_:with:)`
  - State inspection with `isActive(_:)`, `hasActiveOperations`, `error(for:)`
  - Automatic operation tracking with `run(_:task:)`

- **StateError**: structured error information
  - `code`, `message`, `underlying` properties
  - Conversion from a standard Error with `init(from: Error)`

### Documentation

- README.md (Japanese and English)
- RELEASE_PROCESS.md

[Unreleased]: https://github.com/no-problem-dev/swift-statable/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/no-problem-dev/swift-statable/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/no-problem-dev/swift-statable/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/no-problem-dev/swift-statable/releases/tag/v1.0.0

<!-- Auto-generated on 2025-12-31T22:22:38Z by release workflow -->

<!-- Auto-generated on 2025-12-31T23:01:32Z by release workflow -->
