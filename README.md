# Statable

English | [日本語](./README.ja.md)

A declarative state management macro for SwiftUI. Combines the AsyncValue pattern with OperationTracker to manage asynchronous state in a type-safe manner.

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![iOS 17+](https://img.shields.io/badge/iOS-17+-blue.svg)
![macOS 14+](https://img.shields.io/badge/macOS-14+-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **Declarative Macro**: Reduce state management boilerplate with the `@Statable` macro
- **Exclusive State Representation**: Type-safe expression of `.idle`, `.loading`, `.loaded`, `.failed` with `AsyncState<T>` enum
- **Operation Tracking**: Track multiple concurrent operations individually with `OperationTracker`
- **@Observable Integration**: Fully integrated with SwiftUI's `@Observable`
- **Main-actor by construction**: `AsyncValue` and `OperationTracker` are `@MainActor`, so state
  transitions can never race with SwiftUI's reads — the compiler enforces it, not a comment
- **Last-started-wins**: overlapping loads settle deterministically; a slow earlier load can never
  overwrite a newer result
- **Cancellation is not failure**: a cancelled load returns to the previous value instead of
  showing an error or getting stuck in `loading`

## Quick Start

```swift
import SwiftUI
import Statable

// Simple Store definition
@Statable(MetabolicProfile.self)
@MainActor @Observable
final class ProfileStore {
    public init() {}

    var currentAge: Int { value?.age() ?? 0 }
}

// Store with operation tracking
enum WorkoutOperation: String, CaseIterable, Sendable {
    case fetch, recordStrength, recordCardio
}

@Statable([WorkoutActivity].self, operations: WorkoutOperation.self)
@MainActor @Observable
final class WorkoutStore {
    public init() {}

    var isRecording: Bool {
        operations.isActive(.recordStrength) || operations.isActive(.recordCardio)
    }
}
```

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-statable.git", from: "2.0.0")
]
```

Add to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Statable", package: "swift-statable")
    ]
)
```

## Usage

### Basic Store

```swift
@Statable(UserProfile.self)
@MainActor @Observable
final class UserStore {
    public init() {}
}

// Usage in View
struct ProfileView: View {
    @Environment(UserStore.self) private var store

    var body: some View {
        switch store.state {
        case .idle:
            Text("No data")
        case .loading(let previous):
            VStack {
                ProgressView()
                if let prev = previous {
                    Text("Previous: \(prev.name)")
                }
            }
        case .loaded(let profile):
            Text("Hello, \(profile.name)")
        case .failed(let error):
            Text("Error: \(error.localizedMessage)")
        }
    }
}
```

### Loading Data

```swift
// Basic load
await store.load {
    try await api.fetchProfile()
}

// Load only if the last load has not succeeded
await store.loadIfNeeded {
    try await api.fetchProfile()
}
```

### Operation Tracking

```swift
enum DataOperation: String, CaseIterable, Sendable {
    case fetch, save, delete
}

@Statable([Item].self, operations: DataOperation.self)
@MainActor @Observable
final class ItemStore {
    public init() {}
}

// Tracking operations
struct ItemListView: View {
    @Environment(ItemStore.self) private var store

    var body: some View {
        List {
            if store.operations.isActive(.fetch) {
                ProgressView("Loading...")
            }

            ForEach(store.value ?? []) { item in
                ItemRow(item: item)
            }
        }
        .toolbar {
            Button("Save") {
                Task {
                    await store.operations.run(.save) {
                        try await api.saveItems(store.value ?? [])
                    }
                }
            }
            .disabled(store.operations.isActive(.save))
        }
    }
}
```

## API Reference

### @Statable Macro

#### Generated Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | `T?` | Current value |
| `state` | `AsyncState<T>` | State (for switch) |
| `isLoading` | `Bool` | Whether loading |
| `isInitialLoading` | `Bool` | Loading with no value yet — the only state that should show a skeleton |
| `isReloading` | `Bool` | Loading while holding a previous value — do not blank the screen |
| `isIdle` | `Bool` | Whether idle |
| `isFailed` | `Bool` | Whether failed |
| `hasValue` | `Bool` | Whether there is something to show (true in `loading`/`failed` if a previous value exists) |
| `isLoaded` | `Bool` | Whether the last load finished successfully |
| `error` | `StateError?` | Error |
| `operations` | `OperationTracker<Op>` | Operation tracker (only with operations argument) |

#### Generated Methods

| Method | Description |
|--------|-------------|
| `set(_:)` | Set value |
| `setError(_:)` | Set error |
| `startLoading()` | Start loading |
| `reset()` | Reset to initial state |
| `load(_:)` | Execute async operation (last-started-wins; cancellation is not failure) |
| `loadIfNeeded(_:)` | Load only if the last load has not succeeded |

### AsyncState

```swift
public enum AsyncState<Value: Sendable>: Sendable {
    case idle                                        // Nothing requested yet
    case loading(previous: Value?)                   // Loading, keeping what was on screen
    case loaded(Value)                               // Load succeeded
    case failed(StateError, previous: Value?)        // Load failed, keeping what was on screen
}
```

`value` returns the previous value in `loading` **and** `failed`, so one check covers
"is there anything to show". That lets a view render exactly three faces:

```swift
if let value = store.value {
    Content(value)                                  // also during reload, also after a failure
    if let error = store.error { Banner(error) }    // failure does not take the screen away
} else if let error = store.error {
    FailureFace(error)                              // only when there is nothing to show
} else {
    Skeleton()                                      // no answer yet
}
```

Do not drive the view from `isLoading` alone: "is it loading" is not a reason to blank the screen.
An empty array is an answer ("none"), so never read `value?.isEmpty` as "no value" — doing that
makes users with zero items see a skeleton on every refresh.

### OperationTracker

```swift
// Start/complete operations
operations.start(.fetch)
operations.complete(.fetch)
operations.fail(.fetch, with: error)

// Check state
operations.isActive(.fetch)
operations.hasActiveOperations
operations.error(for: .fetch)

// Convenience method
await operations.run(.fetch) {
    try await api.fetchData()
}
```

### StateError

```swift
public enum StateError: Error, Sendable, Equatable, Hashable {
    case network(NetworkError)
    case validation(ValidationError)
    case notFound(resource: String)
    case unauthorized
    case server(code: Int, message: String)
    case unknown(String)
}

// Convenience properties
error.localizedMessage  // User-facing message
error.isRetryable       // Whether retry is appropriate

// Convert from standard Error
let stateError = StateError(from: someError)
```

## Design Principles

### 1 Store = 1 AsyncValue

Each Store manages a single type of async value. This ensures:
- State consistency
- Easy testing
- Clear responsibilities

### SSOT (Single Source of Truth)

The `AsyncState` enum represents exclusive states, preventing contradictory states (e.g., `isLoading = true` AND `error != nil`) at the type level.

### Previous Value During Loading and Failure

Both `loading` and `failed` carry the previous value. Throwing it away is a decision only the view
can make correctly — if the state makes it first, the view has no choice left.

### Main Actor by Construction

`AsyncValue` and `OperationTracker` are `@MainActor`. They *are* view state, and SwiftUI reads them
on the main actor; a write from another thread also delivers Observation's invalidation from that
thread, and a dropped invalidation leaves the view frozen on whatever it drew last — usually a
spinner that never goes away. Up to 1.x this was only a comment next to `@unchecked Sendable`, and
the comment was wrong: `load(_:)` was a `nonisolated async` function, so it hopped off the caller's
actor and mutated state there. `IsolationTests` now measures where the writes happen.

## Migrating from 1.x

| Change | What to do |
|---|---|
| `AsyncValue` / `OperationTracker` are `@MainActor` | Call them from `@MainActor` code. Stores already written as `@MainActor @Observable` need no change |
| `AsyncState.failed` carries `previous` | Update exhaustive `switch` over `state`. `value` now returns the previous value on failure — a view that used `value == nil` to detect failure should read `error` instead |
| `reload(_:)` removed | Use `load(_:)`; it was the same behaviour under a second name |
| `loadIfNeeded(_:)` skips only on success | It now retries after a failure that left a previous value |
| `OperationTracker.run(_:task:)` returns `Result?` | `nil` means the task was cancelled — cancellation is no longer recorded as a failure |
| `AsyncStateProvider` / `OperationTrackable` / `ActorIsolation` removed | Nothing conformed to them; the default implementations silently returned `nil` and did nothing |
| `description` / `debugDescription` / `Equatable` on `AsyncValue` removed | Print or compare `store.state` instead |

## Documentation

Detailed API documentation is available on [GitHub Pages](https://no-problem-dev.github.io/swift-statable/documentation/statable/).

## Dependencies

| Package | Purpose |
|---------|---------|
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | Macro implementation |

## License

MIT License - See [LICENSE](LICENSE) for details.
