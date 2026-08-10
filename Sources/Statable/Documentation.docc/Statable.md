# ``Statable``

A declarative state management macro library for SwiftUI.

@Metadata {
    @PageColor(blue)
}

## Overview

Statable manages asynchronous state in a SwiftUI application in a type-safe way. The `@Statable`
macro removes most of the boilerplate, and the `AsyncState<T>` enum keeps the states exclusive so
no two of them can be true at once.

### Features

- **A declarative macro**: `@Statable` generates the state-handling members for you
- **Exclusive states**: `.idle`, `.loading`, `.loaded` and `.failed` in one `AsyncState<T>` enum
- **Operation tracking**: `OperationTracker` follows several concurrent operations one by one
- **Built on @Observable**: fully integrated with SwiftUI's `@Observable`
- **Sendable throughout**: ready for strict concurrency

### Quick start

```swift
import SwiftUI
import Statable

@Statable(UserProfile.self)
@MainActor @Observable
final class ProfileStore {
    public init() {}

    var displayName: String { value?.name ?? "Guest" }
}

struct ProfileView: View {
    @Environment(ProfileStore.self) private var store

    var body: some View {
        if let profile = store.value {
            Text("Hello, \(profile.name)")
            if let error = store.error { Banner(error) }
        } else if let error = store.error {
            FailureFace(error)
        } else {
            Skeleton()
        }
    }
}
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:DesignPrinciples>

### The macros

- ``Statable(_:)``
- ``Statable(_:operations:)``
- ``Track(_:)``

### State

- ``AsyncState``
- ``AsyncValue``
- <doc:AsyncStateGuide>

### Operation tracking

- ``OperationTracker``
- <doc:OperationTrackerGuide>

### Errors

- ``StateError``
- ``NetworkError``
- ``ValidationError``

### Protocols

- ``Statable-swift.protocol``
