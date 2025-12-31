import Testing
import Foundation
@testable import Statable

@Suite("StateError Tests")
struct StateErrorTests {

    // MARK: - Retryable

    @Test("Network errors are retryable")
    func networkErrorsRetryable() {
        let errors: [StateError] = [
            .network(.timeout),
            .network(.noConnection),
            .network(.unreachable),
        ]

        for error in errors {
            #expect(error.isRetryable, "Expected \(error) to be retryable")
        }
    }

    @Test("Server errors 5xx are retryable")
    func serverErrors5xxRetryable() {
        let retryable = StateError.server(code: 500, message: "Internal Server Error")
        let alsoRetryable = StateError.server(code: 503, message: "Service Unavailable")

        #expect(retryable.isRetryable)
        #expect(alsoRetryable.isRetryable)
    }

    @Test("Server errors 4xx are not retryable")
    func serverErrors4xxNotRetryable() {
        let notRetryable = StateError.server(code: 400, message: "Bad Request")
        let alsoNotRetryable = StateError.server(code: 404, message: "Not Found")

        #expect(!notRetryable.isRetryable)
        #expect(!alsoNotRetryable.isRetryable)
    }

    @Test("Validation errors are not retryable")
    func validationErrorsNotRetryable() {
        let error = StateError.validation(.required(field: "email"))

        #expect(!error.isRetryable)
    }

    @Test("Unauthorized is not retryable")
    func unauthorizedNotRetryable() {
        let error = StateError.unauthorized

        #expect(!error.isRetryable)
    }

    @Test("NotFound is not retryable")
    func notFoundNotRetryable() {
        let error = StateError.notFound(resource: "User")

        #expect(!error.isRetryable)
    }

    // MARK: - Localized Message

    @Test("Network error messages")
    func networkErrorMessages() {
        #expect(StateError.network(.timeout).localizedMessage.contains("タイムアウト"))
        #expect(StateError.network(.noConnection).localizedMessage.contains("接続"))
        #expect(StateError.network(.unreachable).localizedMessage.contains("接続"))
    }

    @Test("Validation error messages")
    func validationErrorMessages() {
        let required = StateError.validation(.required(field: "名前"))
        #expect(required.localizedMessage.contains("名前"))
        #expect(required.localizedMessage.contains("必須"))

        let outOfRange = StateError.validation(.outOfRange(field: "年齢", min: 18, max: 100))
        #expect(outOfRange.localizedMessage.contains("年齢"))
        #expect(outOfRange.localizedMessage.contains("18"))
        #expect(outOfRange.localizedMessage.contains("100"))
    }

    @Test("NotFound error message")
    func notFoundErrorMessage() {
        let error = StateError.notFound(resource: "ユーザー")
        #expect(error.localizedMessage.contains("ユーザー"))
        #expect(error.localizedMessage.contains("見つかりません"))
    }

    // MARK: - Initialization from Error

    @Test("Initialize from URLError timeout")
    func initFromURLErrorTimeout() {
        let urlError = URLError(.timedOut)
        let stateError = StateError(from: urlError)

        #expect(stateError == .network(.timeout))
    }

    @Test("Initialize from URLError not connected")
    func initFromURLErrorNotConnected() {
        let urlError = URLError(.notConnectedToInternet)
        let stateError = StateError(from: urlError)

        #expect(stateError == .network(.noConnection))
    }

    @Test("Initialize from unknown error")
    func initFromUnknownError() {
        let error = TestError.unknown
        let stateError = StateError(from: error)

        if case .unknown = stateError {
            // Expected
        } else {
            Issue.record("Expected unknown error")
        }
    }

    @Test("Initialize from StateError returns same")
    func initFromStateError() {
        let original = StateError.unauthorized
        let converted = StateError(from: original)

        #expect(converted == original)
    }

    // MARK: - Equatable

    @Test("Equatable conformance")
    func equatable() {
        let error1 = StateError.network(.timeout)
        let error2 = StateError.network(.timeout)
        let error3 = StateError.network(.noConnection)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case unknown
}
