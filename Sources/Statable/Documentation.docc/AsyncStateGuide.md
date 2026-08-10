# AsyncState Guide

Working with the exclusive state of an asynchronously loaded value.

## Overview

``AsyncState`` is the enum that expresses the state of a value being loaded asynchronously. It is
a single source of truth: one enum holds every state, and the states are exclusive, so no two of
them can be true at once.

## The cases

```swift
public enum AsyncState<Value: Sendable>: Sendable {
    case idle                                  // nothing asked for yet
    case loading(previous: Value?)             // in flight, carrying what was on screen
    case loaded(Value)                         // finished successfully
    case failed(StateError, previous: Value?)  // failed, still carrying what was on screen
}
```

### idle

Nothing has been asked for yet: just after launch, or after an explicit reset.

```swift
if store.isIdle {
    Button("Load") { Task { await store.load { try await api.fetchProfile() } } }
}
```

### loading

A load is in flight. `previous` carries whatever was already on screen, so a reload can keep
showing the last answer instead of blanking out.

```swift
if store.isInitialLoading {
    Skeleton()              // nothing to show yet — a skeleton is honest here
} else if store.isReloading {
    Content(store.value!)   // keep the previous answer up and swap it quietly
}
```

### loaded

The load finished successfully. This is the only case that counts as done for `loadIfNeeded(_:)`.

```swift
case .loaded(let profile):
    ProfileView(profile: profile)
```

### failed

The load failed. The failure comes with a ``StateError``, and `previous` still holds whatever was
on screen — a failure does not take the screen away by itself.

```swift
case .failed(let error, let previous):
    if let previous {
        Content(previous)
        Banner(error)
    } else {
        FailureFace(error)
    }
```

## Convenience properties

| Property | What it tells you |
|----------|-------------------|
| `value` | What can be shown now: the loaded value, or the previous one during a reload or after a failure |
| `hasValue` | Whether there is anything to show at all |
| `isLoading` | Whether a load is in flight |
| `isInitialLoading` | In flight with nothing to show yet — the only state in which a skeleton belongs |
| `isReloading` | In flight with the previous value still shown |
| `isLoaded` | Whether the last load finished successfully; a value left over from before a failure does not count |
| `isIdle` | Whether nothing has been asked for yet |
| `isFailed` | Whether the last load failed |
| `error` | The failure from the last load |

## AsyncValue

``AsyncValue`` is the `@Observable` class that holds an ``AsyncState`` for you; `@Statable` uses
one internally. It is `@MainActor`, because it is view state and SwiftUI reads it there.

### Transitions

```swift
// Store a value directly
store.set(newProfile)

// Record a failure, keeping the previous value on screen
store.setError(.notFound(resource: "profile"))

// Mark a load as started, keeping the previous value on screen
store.startLoading()

// Drop the value and the error
store.reset()
```

Each of these supersedes a load that is still in flight: a value you placed explicitly is newer
information than work that has not come back yet.

### Running the work for you

```swift
// Run and reflect the outcome
await store.load {
    try await api.fetchProfile()
}

// Load only when no load has succeeded yet
await store.loadIfNeeded {
    try await api.fetchProfile()
}
```

`load(_:)` settles overlapping loads so that the last one started wins, and treats cancellation as
neither success nor failure — the previous value comes back rather than an error appearing or the
state being stranded in `loading`.

## Best practices

### Render three faces, not four cases

Switching over all four cases is fine when each really does need its own layout, but most screens
want this instead:

```swift
if let value = store.value {
    Content(value)                                  // during a reload, and after a failure
    if let error = store.error { Banner(error) }    // a failure speaks in a banner
} else if let error = store.error {
    FailureFace(error)                              // only when there is nothing to show
} else {
    Skeleton()                                      // no answer yet
}
```

### An empty collection is an answer

Never read `value?.isEmpty` as "there is no value". An empty array means "none", which is a real
answer — treating it as missing makes users with zero items, and only those users, watch a
skeleton on every refresh.

## See Also

- ``AsyncState``
- ``AsyncValue``
- ``StateError``
- <doc:DesignPrinciples>
