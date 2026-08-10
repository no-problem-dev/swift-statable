import Foundation

/// A failure sorted into the kinds a screen actually has to act on differently.
///
/// The case a failure lands in decides how it can be recovered from.
///
/// ## Example
///
/// ```swift
/// if let error = store.profile.error {
///     Text(error.localizedMessage)
///     if error.isRetryable {
///         Button("Try again") { retry() }
///     }
/// }
/// ```
public enum StateError: Error, Sendable, Equatable, Hashable {
    /// A transport failure. Every error in this case is treated as worth retrying.
    case network(NetworkError)

    /// Input the user has to correct, which retrying on its own will never fix.
    case validation(ValidationError)

    case notFound(resource: String)

    case unauthorized

    /// A failure the server reported. Codes of 500 and above are treated as worth retrying.
    case server(code: Int, message: String)

    /// A failure that could not be sorted, carrying the description it came with.
    case unknown(String)
}

// MARK: - NetworkError

/// The transport failures recognised when converting an error from URLSession.
public enum NetworkError: Sendable, Equatable, Hashable {
    case timeout

    /// The device has no usable connection, or the connection was lost mid-flight.
    case noConnection

    /// The host could not be found, or refused the connection.
    case unreachable

    /// The secure connection could not be established, or the certificate was not trusted.
    case sslError

    /// The host name could not be resolved.
    case dnsError
}

// MARK: - ValidationError

/// The ways a single field can be wrong, each carrying the field name so a form can point at it.
public enum ValidationError: Sendable, Equatable, Hashable {
    case invalidInput(field: String, reason: String)

    /// A number outside the range the field accepts, which the message quotes back to the user.
    case outOfRange(field: String, min: Double, max: Double)

    /// A field that has to be filled in and was left empty.
    case required(field: String)

    /// A value of the right kind written the wrong way, with the shape that was expected.
    case invalidFormat(field: String, expected: String)
}

// MARK: - Computed Properties

extension StateError {
    /// Whether offering a retry button makes sense.
    ///
    /// Transport failures and server failures of 500 and above are the ones a second attempt can fix.
    public var isRetryable: Bool {
        switch self {
        case .network:
            true
        case .server(let code, _):
            code >= 500
        case .validation, .notFound, .unauthorized, .unknown:
            false
        }
    }

    /// A sentence to put in front of the user.
    ///
    /// The text is fixed Japanese and does not go through a string catalog, so an app that ships in
    /// other languages has to map the case to its own wording rather than show this.
    public var localizedMessage: String {
        switch self {
        case .network(let detail):
            detail.localizedMessage
        case .validation(let detail):
            detail.localizedMessage
        case .notFound(let resource):
            "\(resource)が見つかりません"
        case .unauthorized:
            "認証が必要です"
        case .server(_, let message):
            message
        case .unknown(let message):
            message
        }
    }

    /// A one-line rendering for logs, naming the case and everything it carries.
    public var debugDescription: String {
        switch self {
        case .network(let detail):
            "NetworkError: \(detail)"
        case .validation(let detail):
            "ValidationError: \(detail)"
        case .notFound(let resource):
            "NotFoundError: \(resource)"
        case .unauthorized:
            "UnauthorizedError"
        case .server(let code, let message):
            "ServerError(\(code)): \(message)"
        case .unknown(let message):
            "UnknownError: \(message)"
        }
    }
}

// MARK: - NetworkError Localized Message

extension NetworkError {
    /// A sentence to put in front of the user.
    ///
    /// - Returns: A fixed Japanese sentence describing this kind of transport failure.
    public var localizedMessage: String {
        switch self {
        case .timeout:
            "接続がタイムアウトしました"
        case .noConnection:
            "ネットワークに接続されていません"
        case .unreachable:
            "サーバーに接続できません"
        case .sslError:
            "安全な接続を確立できませんでした"
        case .dnsError:
            "サーバーが見つかりません"
        }
    }
}

// MARK: - ValidationError Localized Message

extension ValidationError {
    /// A sentence to put in front of the user.
    ///
    /// - Returns: A fixed Japanese sentence naming the field and what is wrong with it.
    public var localizedMessage: String {
        switch self {
        case .invalidInput(let field, let reason):
            "\(field): \(reason)"
        case .outOfRange(let field, let min, let max):
            "\(field)は\(Int(min))〜\(Int(max))の範囲で入力してください"
        case .required(let field):
            "\(field)は必須です"
        case .invalidFormat(let field, let expected):
            "\(field)の形式が正しくありません（\(expected)）"
        }
    }
}

// MARK: - Convenience Initializers

extension StateError {
    /// Sorts an arbitrary error into one of these cases.
    ///
    /// A URLError is mapped to the transport failure it describes; anything unrecognised keeps its
    /// localized description and lands in the unsorted case.
    public init(from error: Error) {
        if let stateError = error as? StateError {
            self = stateError
            return
        }

        // Map the URLError codes this library recognises.
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                self = .network(.timeout)
            case .notConnectedToInternet, .networkConnectionLost:
                self = .network(.noConnection)
            case .cannotFindHost, .cannotConnectToHost:
                self = .network(.unreachable)
            case .secureConnectionFailed, .serverCertificateUntrusted:
                self = .network(.sslError)
            case .dnsLookupFailed:
                self = .network(.dnsError)
            default:
                self = .unknown(urlError.localizedDescription)
            }
            return
        }

        self = .unknown(error.localizedDescription)
    }
}
