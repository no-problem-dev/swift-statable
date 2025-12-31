import Foundation

/// 状態管理で扱う構造化エラー
///
/// エラーの種類に応じて適切なリカバリー戦略を決定できます。
///
/// ## 使用例
///
/// ```swift
/// if let error = store.profile.error {
///     Text(error.localizedMessage)
///     if error.isRetryable {
///         Button("再試行") { retry() }
///     }
/// }
/// ```
public enum StateError: Error, Sendable, Equatable, Hashable {
    /// ネットワークエラー
    case network(NetworkError)

    /// バリデーションエラー
    case validation(ValidationError)

    /// リソースが見つからない
    case notFound(resource: String)

    /// 認証エラー
    case unauthorized

    /// サーバーエラー
    case server(code: Int, message: String)

    /// 不明なエラー
    case unknown(String)
}

// MARK: - NetworkError

/// ネットワーク関連のエラー詳細
public enum NetworkError: Sendable, Equatable, Hashable {
    /// 接続タイムアウト
    case timeout

    /// ネットワーク未接続
    case noConnection

    /// サーバー到達不可
    case unreachable

    /// SSL/TLS エラー
    case sslError

    /// DNS解決エラー
    case dnsError
}

// MARK: - ValidationError

/// バリデーション関連のエラー詳細
public enum ValidationError: Sendable, Equatable, Hashable {
    /// 不正な入力
    case invalidInput(field: String, reason: String)

    /// 範囲外の値
    case outOfRange(field: String, min: Double, max: Double)

    /// 必須フィールドが未入力
    case required(field: String)

    /// フォーマット不正
    case invalidFormat(field: String, expected: String)
}

// MARK: - Computed Properties

extension StateError {
    /// リトライ可能かどうか
    ///
    /// ネットワークエラーや一時的なサーバーエラーはリトライ可能と判定します。
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

    /// ユーザー向けのローカライズされたメッセージ
    ///
    /// 将来的にはLocalizedStringKeyを使用したローカライズに対応予定。
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

    /// デバッグ用の詳細説明
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
    /// ユーザー向けメッセージ
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
    /// ユーザー向けメッセージ
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
    /// 標準のErrorからStateErrorを生成
    ///
    /// URLErrorなどの既知のエラー型は適切に変換されます。
    public init(from error: Error) {
        if let stateError = error as? StateError {
            self = stateError
            return
        }

        // URLError の変換
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
