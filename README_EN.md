# Statable

English | [日本語](README.md)

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
- **Sendable Conformance**: Full Strict Concurrency support

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
    .package(url: "https://github.com/no-problem-dev/swift-statable.git", from: "1.0.0")
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
            Text("Error: \(error.message)")
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

// Load only if no value exists
await store.loadIfNeeded {
    try await api.fetchProfile()
}

// Force reload
await store.reload {
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
| `isIdle` | `Bool` | Whether idle |
| `isFailed` | `Bool` | Whether failed |
| `hasValue` | `Bool` | Whether value exists |
| `error` | `StateError?` | Error |
| `operations` | `OperationTracker<Op>` | Operation tracker (only with operations argument) |

#### Generated Methods

| Method | Description |
|--------|-------------|
| `set(_:)` | Set value |
| `setError(_:)` | Set error |
| `startLoading()` | Start loading |
| `reset()` | Reset to initial state |
| `load(_:)` | Execute async operation |
| `loadIfNeeded(_:)` | Load only if no value |
| `reload(_:)` | Force reload |

### AsyncState

```swift
public enum AsyncState<Value: Sendable>: Sendable {
    case idle                       // Initial state
    case loading(previous: Value?)  // Loading (retains previous value)
    case loaded(Value)              // Load succeeded
    case failed(StateError)         // Load failed
}
```

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
public struct StateError: Error, Equatable, Sendable {
    public let code: String
    public let message: String
    public let underlying: String?

    public init(from error: Error)
    public init(code: String, message: String)
}
```

## Design Principles

### 1 Store = 1 AsyncValue

Each Store manages a single type of async value. This ensures:
- State consistency
- Easy testing
- Clear responsibilities

### SSOT (Single Source of Truth)

The `AsyncState` enum represents exclusive states, preventing contradictory states (e.g., `isLoading = true` AND `error != nil`) at the type level.

### Previous Value During Loading

`loading(previous: Value?)` allows displaying the previous value during reload, improving UX.

## Documentation

Detailed API documentation is available on [GitHub Pages](https://no-problem-dev.github.io/swift-statable/documentation/statable/).

## Dependencies

| Package | Purpose |
|---------|---------|
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | Macro implementation |

## License

MIT License - See [LICENSE](LICENSE) for details.
