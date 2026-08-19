import Foundation

public struct CodexAppServerUsageProvider: UsageProviding {
    private let codexExecutablePath: String
    private let timeoutSeconds: Int
    private let maximumAttempts: Int

    public init(
        codexExecutablePath: String? = nil,
        timeoutSeconds: Int = 10,
        maximumAttempts: Int = 2
    ) {
        self.codexExecutablePath = codexExecutablePath
            ?? Self.resolveCodexExecutablePath(from: Self.defaultCodexExecutablePaths)
            ?? Self.defaultCodexExecutablePaths[0]
        self.timeoutSeconds = timeoutSeconds
        self.maximumAttempts = max(maximumAttempts, 1)
    }

    static func resolveCodexExecutablePath(
        from candidates: [String],
        isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)
    ) -> String? {
        candidates.first(where: isExecutable)
    }

    public func fetchUsage() -> Result<CodexUsageSnapshot, UsageProviderError> {
        guard FileManager.default.isExecutableFile(atPath: codexExecutablePath) else {
            return .failure(.missingAuth)
        }

        for _ in 0..<maximumAttempts {
            let output = runAppServerRead()
            if let snapshot = Self.extractRateLimitSnapshot(from: output) {
                return .success(snapshot)
            }
        }
        return .failure(.invalidResponse)
    }

    private func runAppServerRead() -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", shellScript()]
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return stdout + "\n" + stderr
    }

    private func shellScript() -> String {
        let initialize = """
        {"id":1,"method":"initialize","params":{"clientInfo":{"name":"codex-usage-widget","title":"Codex Usage Widget","version":"0.1.0"},"capabilities":{"experimentalApi":true,"requestAttestation":false,"optOutNotificationMethods":[]}}}
        """
        let initialized = #"{"method":"initialized"}"#
        let read = #"{"id":2,"method":"account/rateLimits/read","params":null}"#

        return """
        (
          /usr/bin/printf '%s\\n' \(shellQuote(initialize))
          /bin/sleep 1
          /usr/bin/printf '%s\\n' \(shellQuote(initialized))
          /bin/sleep 0.5
          /usr/bin/printf '%s\\n' \(shellQuote(read))
          /bin/sleep \(timeoutSeconds)
        ) | \(shellQuote(codexExecutablePath)) app-server --stdio
        """
    }

    static func extractRateLimitSnapshot(from output: String, now: Date = Date()) -> CodexUsageSnapshot? {
        for line in output.split(separator: "\n") {
            guard
                let data = String(line).data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let id = object["id"] as? Int,
                id == 2,
                let result = object["result"] as? [String: Any],
                let resultData = try? JSONSerialization.data(withJSONObject: result)
            else {
                continue
            }
            return CodexRateLimitResponseMapper.map(resultData, now: now)
        }
        return nil
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static var defaultCodexExecutablePaths: [String] {
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true).path
        return [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "\(userApplications)/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(userApplications)/Codex.app/Contents/Resources/codex",
        ]
    }
}
