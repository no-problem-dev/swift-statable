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

## Usage

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

### Rendering

Because `value` returns the previous value in `loading` **and** `failed`, one check covers "is
there anything to show", and a view renders exactly three faces:

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

struct ItemListView: View {
    @Environment(ItemStore.self) private var store

    var body: some View {
        List {
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

## Documentation

The full API reference and the guides live on
[GitHub Pages](https://no-problem-dev.github.io/swift-statable/documentation/statable/), including
[Design Principles](https://no-problem-dev.github.io/swift-statable/documentation/statable/designprinciples)
for why the library is shaped this way.

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

## Dependencies

| Package | Purpose |
|---------|---------|
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | Macro implementation |

## License

MIT License - See [LICENSE](LICENSE) for details.
