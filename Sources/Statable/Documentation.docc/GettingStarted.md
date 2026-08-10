# Getting Started

Learn the basics of managing asynchronous state with Statable.

## Overview

Statable manages asynchronous state in a SwiftUI application in a type-safe way. The `@Statable`
macro removes most of the boilerplate that state handling otherwise spreads across a store.

## Defining a store

Apply the `@Statable` macro to a class, together with `@MainActor` and `@Observable`:

```swift
import Statable

@Statable(UserProfile.self)
@MainActor @Observable
final class ProfileStore {
    public init() {}
}
```

The macro is `@MainActor`-only by construction: the ``AsyncValue`` it generates lives on the main
actor, so leaving `@MainActor` off does not compile. That is deliberate — you find out while
writing the store instead of racing at runtime.

These members are generated for you:

| Property | Type | What it tells you |
|----------|------|-------------------|
| `value` | `T?` | What can be shown now — the previous value survives a reload and a failure |
| `state` | `AsyncState<T>` | The exclusive state, for switching over every case |
| `isLoading` | `Bool` | Whether a load is in flight |
| `isInitialLoading` | `Bool` | In flight with nothing to show yet — the only state for a skeleton |
| `isReloading` | `Bool` | In flight with the previous value still shown — do not empty the screen |
| `hasValue` | `Bool` | Whether there is anything to show at all |
| `isLoaded` | `Bool` | Whether the last load finished successfully |
| `error` | `StateError?` | The failure from the last load |

along with `set(_:)`, `setError(_:)`, `startLoading()`, `reset()`, `load(_:)` and `loadIfNeeded(_:)`.

## Loading data

```swift
// Run the work and reflect its outcome
await store.load {
    try await api.fetchProfile()
}

// Load only when no load has succeeded yet
await store.loadIfNeeded {
    try await api.fetchProfile()
}
```

`load(_:)` handles the awkward parts for you. Overlapping loads settle so that the last one
started wins, and a cancelled load returns to the previous value rather than showing an error or
being stranded in `loading`.

## Rendering in a view

The reliable shape is three faces, not four cases:

```swift
struct ProfileView: View {
    @Environment(ProfileStore.self) private var store

    var body: some View {
        VStack {
            if let profile = store.value {
                Text("Hello, \(profile.name)")
                if let error = store.error {
                    Text(error.localizedMessage)
                        .foregroundStyle(.secondary)
                }
            } else if let error = store.error {
                Text(error.localizedMessage)
                if error.isRetryable {
                    Button("Try again") {
                        Task { await store.load { try await api.fetchProfile() } }
                    }
                }
            } else if store.isInitialLoading {
                ProgressView()
            } else {
                Button("Load") {
                    Task { await store.load { try await api.fetchProfile() } }
                }
            }
        }
    }
}
```

Because `value` returns the previous value in `loading` **and** in `failed`, one check answers
"is there anything to show". Do not decide from `isLoading` alone — being in flight is not a
reason to empty the screen.

## Tracking several operations

When one store performs several distinct operations, pass the `operations` argument:

```swift
enum DataOperation: String, CaseIterable, Sendable {
    case fetch, save, delete
}

@Statable([Item].self, operations: DataOperation.self)
@MainActor @Observable
final class ItemStore {
    public init() {}

    var isSaving: Bool {
        operations.isActive(.save)
    }
}
```

See <doc:OperationTrackerGuide> for the details.

## Next steps

- <doc:DesignPrinciples>: why the library is shaped this way
- <doc:AsyncStateGuide>: working with `AsyncState` directly
- <doc:OperationTrackerGuide>: tracking several operations at once
