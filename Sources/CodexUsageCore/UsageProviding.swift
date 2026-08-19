import Foundation

public protocol UsageProviding: Sendable {
    func fetchUsage() -> Result<CodexUsageSnapshot, UsageProviderError>
}

public enum UsageProviderError: Error, Equatable, Sendable {
    /// `auth.json` 缺失或 `access_token` 为空。
    case missingAuth
    /// HTTP 401/403，需要重新登录 Codex。
    case unauthorized
    /// 网络不可达、超时或非 2xx 状态码。
    case network(String)
    /// 响应结构无法解码。
    case invalidResponse
}

public enum UsageProviderErrorDisplayFormatter {
    public static func errorText(_ error: UsageProviderError) -> String {
        switch error {
        case .missingAuth, .unauthorized:
            return "无法获取用量，请打开 Codex 重新登录。"
        case .network(let reason):
            return "无法获取用量：\(reason)"
        case .invalidResponse:
            return "无法获取用量，响应格式已变化。"
        }
    }
}
