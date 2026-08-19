import Foundation

/// 直连 ChatGPT 后端只读端点获取 Codex 用量，凭据只读本机 Codex 登录态。
public struct WhamUsageProvider: UsageProviding {
    private let authFileURL: URL
    private let endpoint: URL
    private let timeout: TimeInterval

    public init(
        authFileURL: URL = ResetCreditExpiryProvider.defaultAuthFileURL(),
        endpoint: URL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
        timeout: TimeInterval = 15
    ) {
        self.authFileURL = authFileURL
        self.endpoint = endpoint
        self.timeout = timeout
    }

    public func fetchUsage() -> Result<CodexUsageSnapshot, UsageProviderError> {
        guard
            let credentials = Self.readCredentials(authFileURL: authFileURL)
        else {
            return .failure(.missingAuth)
        }

        var request = URLRequest(url: endpoint, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountId, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("https://chatgpt.com", forHTTPHeaderField: "Origin")
        request.setValue("https://chatgpt.com/", forHTTPHeaderField: "Referer")

        let semaphore = DispatchSemaphore(value: 0)
        let box = LockedBox<Result<CodexUsageSnapshot, UsageProviderError>?>(nil)
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                box.value = .failure(.network(error.localizedDescription))
                return
            }
            if let http = response as? HTTPURLResponse,
               let classified = Self.classify(statusCode: http.statusCode) {
                box.value = .failure(classified)
                return
            }
            guard let data, let snapshot = WhamUsageResponseMapper.map(data) else {
                box.value = .failure(.invalidResponse)
                return
            }
            box.value = .success(snapshot)
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeout)

        return box.value ?? .failure(.network("请求超时"))
    }

    /// HTTP 状态码到错误的分类；2xx 返回 nil。
    static func classify(statusCode: Int) -> UsageProviderError? {
        switch statusCode {
        case 200...299:
            return nil
        case 401, 403:
            return .unauthorized
        default:
            return .network("HTTP \(statusCode)")
        }
    }

    struct Credentials: Equatable {
        let accessToken: String
        let accountId: String
    }

    /// 只读解析 `auth.json` 中的 `tokens.access_token` 与顶层 `account_id`。
    static func readCredentials(authFileURL: URL) -> Credentials? {
        guard FileManager.default.fileExists(atPath: authFileURL.path) else {
            return nil
        }
        guard
            let data = try? Data(contentsOf: authFileURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = object["tokens"] as? [String: Any],
            let accessToken = tokens["access_token"] as? String,
            !accessToken.isEmpty
        else {
            return nil
        }
        let accountId = object["account_id"] as? String ?? ""
        return Credentials(accessToken: accessToken, accountId: accountId)
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        self.storage = value
    }

    var value: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            storage = newValue
            lock.unlock()
        }
    }
}
