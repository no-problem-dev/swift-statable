# Design Principles

Why the library is shaped this way, and what each decision buys you.

## Overview

Four decisions account for almost everything in the API. Each of them exists because the obvious
alternative produced a bug that was hard to see and easy to ship.

## One store, one AsyncValue

Each store owns a single type of asynchronously loaded value. Keeping it to one means the state is
consistent by construction, the store is easy to test, and its responsibility is obvious from its
name. A store that owns three values has eight combinations of loading flags, and no view reads all
eight correctly.

When a store genuinely does several things to that one value, the operations belong in an
``OperationTracker`` rather than in more values.

## A single source of truth

``AsyncState`` is an exclusive enum, so contradictory states cannot be written down. The classic
pair of a `isLoading: Bool` and an `error: Error?` allows `isLoading == true` while `error != nil`,
and every view that reads them has to decide what that combination means. Here it cannot be
constructed, so nobody has to decide.

## Loading and failure keep the previous value

Both `loading` and `failed` carry the previous value across the transition. Throwing it away is a
decision only the view can make correctly — if the state makes it first, the view has no choice
left.

That is what lets a view render exactly three faces:

```swift
if let value = store.value {
    Content(value)                                  // during a reload, and after a failure
    if let error = store.error { Banner(error) }    // a failure does not take the screen away
} else if let error = store.error {
    FailureFace(error)                              // only when there is nothing to show
} else {
    Skeleton()                                      // no answer yet
}
```

Do not drive a view from `isLoading` alone: being in flight is not a reason to empty the screen.
An empty array is an answer — "none" — so never read `value?.isEmpty` as "there is no value".
Doing that makes users with zero items, and only those users, watch a skeleton on every refresh.

## Main actor by construction

``AsyncValue`` and ``OperationTracker`` are `@MainActor`. They *are* view state, and SwiftUI reads
them on the main actor. A write from another thread delivers Observation's invalidation from that
thread too, and a dropped invalidation leaves the view frozen on whatever it drew last — usually a
spinner that never goes away.

Up to 1.x this was only a note next to `@unchecked Sendable`, and the note was wrong: `load(_:)`
was a `nonisolated async` function, so it hopped off the caller's actor and mutated state there.
`IsolationTests` now measures where the writes actually happen, so the guarantee is checked rather
than asserted.

## Overlapping loads settle by start order

When two loads for the same value overlap, the one that finishes last would naturally win — which
means a slow earlier failure can paint over a newer success. ``AsyncValue`` numbers each start and
only writes a result back while that number is still current, so **the last one started wins**.

Cancellation is treated as neither success nor failure: the previous value comes back. Stopping
work because someone left the screen or retyped a query is not something to show a person in red,
and leaving the state in `loading` instead is what produces a spinner that outlives the screen.

## See Also

- ``AsyncState``
- ``AsyncValue``
- ``OperationTracker``
