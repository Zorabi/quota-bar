import Foundation

public struct ResetCreditExpirySnapshot: Equatable, Sendable {
    public let availableCount: Int
    public let expirations: [Date]
    public let fetchedAt: Date

    public init(availableCount: Int, expirations: [Date], fetchedAt: Date = Date()) {
        self.availableCount = availableCount
        self.expirations = expirations.sorted()
        self.fetchedAt = fetchedAt
    }
}

public enum ResetCreditExpiryQueryError: Error, Equatable, Sendable {
    case missingAuthFile
    case missingAccessToken
    case requestFailed(String)
    case invalidResponse
}

public protocol ResetCreditExpiryProviding: Sendable {
    func fetchExpirySnapshot() -> Result<ResetCreditExpirySnapshot, ResetCreditExpiryQueryError>
}

public struct ResetCreditExpiryProvider: ResetCreditExpiryProviding {
    private let authFileURL: URL
    private let endpoint: URL
    private let timeout: TimeInterval

    public init(
        authFileURL: URL = ResetCreditExpiryProvider.defaultAuthFileURL(),
        endpoint: URL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!,
        timeout: TimeInterval = 20
    ) {
        self.authFileURL = authFileURL
        self.endpoint = endpoint
        self.timeout = timeout
    }

    public func fetchExpirySnapshot() -> Result<ResetCreditExpirySnapshot, ResetCreditExpiryQueryError> {
        let tokenResult = accessToken()
        guard case let .success(token) = tokenResult else {
            return .failure(tokenResult.failure ?? .missingAccessToken)
        }

        var request = URLRequest(url: endpoint, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("https://chatgpt.com", forHTTPHeaderField: "Origin")
        request.setValue("https://chatgpt.com/", forHTTPHeaderField: "Referer")

        let semaphore = DispatchSemaphore(value: 0)
        let box = LockedBox<Result<ResetCreditExpirySnapshot, ResetCreditExpiryQueryError>?>(nil)
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                box.value = .failure(.requestFailed(error.localizedDescription))
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                box.value = .failure(.requestFailed("HTTP \(http.statusCode)"))
                return
            }
            guard let data else {
                box.value = .failure(.invalidResponse)
                return
            }
            do {
                box.value = .success(try ResetCreditExpiryResponseMapper.map(data))
            } catch let queryError as ResetCreditExpiryQueryError {
                box.value = .failure(queryError)
            } catch {
                box.value = .failure(.invalidResponse)
            }
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeout)
        return box.value ?? .failure(.requestFailed("请求超时"))
    }

    public static func defaultAuthFileURL() -> URL {
        let base = ProcessInfo.processInfo.environment["CODEX_HOME"].map(URL.init(fileURLWithPath:))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        return base.appendingPathComponent("auth.json")
    }

    private func accessToken() -> Result<String, ResetCreditExpiryQueryError> {
        guard FileManager.default.fileExists(atPath: authFileURL.path) else {
            return .failure(.missingAuthFile)
        }
        guard
            let data = try? Data(contentsOf: authFileURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = object["tokens"] as? [String: Any],
            let token = tokens["access_token"] as? String,
            !token.isEmpty
        else {
            return .failure(.missingAccessToken)
        }
        return .success(token)
    }
}

public enum ResetCreditExpiryResponseMapper {
    public static func map(_ data: Data, fetchedAt: Date = Date()) throws -> ResetCreditExpirySnapshot {
        let response: WhamResetCreditResponse
        do {
            response = try JSONDecoder().decode(WhamResetCreditResponse.self, from: data)
        } catch {
            throw ResetCreditExpiryQueryError.invalidResponse
        }
        let expirations = response.credits.compactMap { parseDate($0.expiresAt) }.sorted()
        return ResetCreditExpirySnapshot(
            availableCount: response.availableCount,
            expirations: expirations,
            fetchedAt: fetchedAt
        )
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

private struct WhamResetCreditResponse: Decodable {
    let availableCount: Int
    let credits: [WhamResetCredit]

    private enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
        case credits
    }
}

private struct WhamResetCredit: Decodable {
    let expiresAt: String

    private enum CodingKeys: String, CodingKey {
        case expiresAt = "expires_at"
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

private extension Result {
    var failure: Failure? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }
}
