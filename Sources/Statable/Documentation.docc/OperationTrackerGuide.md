# OperationTracker Guide

Following several concurrent operations one by one.

## Overview

``OperationTracker`` tracks several concurrent operations separately, so "fetching" and "saving"
can be in flight at the same time and each can drive its own part of the UI.

## Basic use

### Declaring the operations

Describe the operations you want to track as an enum:

```swift
enum DataOperation: String, CaseIterable, Sendable {
    case fetch
    case save
    case delete
}
```

### Attaching it to a store

Pass the operation type to `@Statable` through the `operations` argument:

```swift
@Statable([Item].self, operations: DataOperation.self)
@MainActor @Observable
final class ItemStore {
    public init() {}
}
```

The `operations` property is generated for you. Use `@Track` instead when a store needs a tracker
that is independent of its value.

## The lifecycle of an operation

### By hand

```swift
store.operations.start(.fetch)
store.operations.complete(.fetch)
store.operations.fail(.fetch, with: error)
```

`start(_:)` also clears the error left over from the operation's last attempt, so a retry does not
show the previous failure while it runs.

### Automatically, which is what you usually want

`run(_:task:)` handles starting, completing and failing:

```swift
let result = await store.operations.run(.fetch) {
    try await api.fetchItems()
}

switch result {
case .success(let items):
    store.set(items)
case .failure:
    break               // the failure is already recorded on the tracker
case nil:
    break               // the task was cancelled, which is not a failure
}
```

The return type is `Result<T, StateError>?`, and `nil` means the task was cancelled. Cancellation
is deliberately not recorded as a failure: work that was merely called off should not leave a red
message nobody remembers asking for.

### Sending the result straight into the value

`run(_:into:task:)` tracks the operation and lets ``AsyncValue/load(_:)`` own the state
transitions, so the rules about overlap and cancellation are not written twice. It takes an
``AsyncValue`` the store owns itself, which pairs with `@Track` rather than with `@Statable`:

```swift
@MainActor @Observable
final class ItemStore {
    let items = AsyncValue<[Item]>()

    @Track(DataOperation.self) var operations

    func refresh() async {
        await operations.run(.fetch, into: items) {
            try await api.fetchItems()
        }
    }
}
```

## Reading the state

### One operation at a time

```swift
if store.operations.isActive(.save) {
    ProgressView("Saving…")
}

if let error = store.operations.error(for: .fetch) {
    Text(error.localizedMessage)
}
```

### Everything at once

```swift
if store.operations.hasActiveOperations {
    // something is in flight
}

for operation in store.operations.active {
    print("\(operation) is running")
}

if store.operations.hasErrors {
    for (operation, error) in store.operations.allErrors {
        print("\(operation): \(error.localizedMessage)")
    }
}
```

## Clearing errors

```swift
store.operations.clearError(for: .fetch)
store.operations.clearAllErrors()
```

## A worked example

### A CRUD screen

```swift
enum TodoOperation: String, CaseIterable, Sendable {
    case fetch, create, update, delete
}

@Statable([Todo].self, operations: TodoOperation.self)
@MainActor @Observable
final class TodoStore {
    public init() {}

    var isModifying: Bool {
        operations.isActive(.create) ||
        operations.isActive(.update) ||
        operations.isActive(.delete)
    }
}

struct TodoListView: View {
    @Environment(TodoStore.self) private var store

    var body: some View {
        List {
            if store.isInitialLoading {
                ProgressView("Loading…")
            }

            ForEach(store.value ?? []) { todo in
                TodoRow(todo: todo)
            }
            .deleteDisabled(store.isModifying)
        }
        .toolbar {
            if store.isModifying {
                ProgressView()
            }
        }
        .task {
            let result = await store.operations.run(.fetch) {
                try await api.fetchTodos()
            }
            if case .success(let todos) = result {
                store.set(todos)
            }
        }
    }
}
```

### Independent operations in parallel

```swift
await withTaskGroup(of: Void.self) { group in
    group.addTask {
        await store.operations.run(.fetchProfile) {
            try await api.fetchProfile()
        }
    }
    group.addTask {
        await store.operations.run(.fetchSettings) {
            try await api.fetchSettings()
        }
    }
}
```

## Best practices

### Choose the granularity from the UI

Split an operation out when the UI has to show its state separately, and not before:

```swift
// Good: each one drives something visible
enum GoodOperations {
    case fetchList
    case saveItem
    case deleteItem
}

// Bad: the phases of one operation are already tracked for you
enum BadOperations {
    case fetchListStart
    case fetchListProcess
    case fetchListComplete
}
```

### Offering a retry

```swift
if let error = store.operations.error(for: .fetch) {
    VStack {
        Text(error.localizedMessage)
        if error.isRetryable {
            Button("Try again") {
                Task {
                    await store.operations.run(.fetch) { try await api.fetchItems() }
                }
            }
        }
    }
}
```

`run(_:task:)` starts by clearing the operation's recorded error, so the message disappears as the
retry begins without you clearing it yourself.

## See Also

- ``OperationTracker``
- ``StateError``
- <doc:GettingStarted>
