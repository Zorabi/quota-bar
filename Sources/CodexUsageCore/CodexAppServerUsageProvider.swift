import Foundation

public struct CodexAppServerUsageProvider: UsageProviding {
    private let codexExecutablePath: String
    private let timeoutSeconds: Int

    public init(
        codexExecutablePath: String = "/Applications/Codex.app/Contents/Resources/codex",
        timeoutSeconds: Int = 2
    ) {
        self.codexExecutablePath = codexExecutablePath
        self.timeoutSeconds = timeoutSeconds
    }

    public func fetchUsage() -> CodexUsageSnapshot? {
        guard FileManager.default.isExecutableFile(atPath: codexExecutablePath) else {
            return nil
        }

        let output = runAppServerRead()
        return extractRateLimitSnapshot(from: output)
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
          /bin/sleep 0.2
          /usr/bin/printf '%s\\n' \(shellQuote(initialized))
          /usr/bin/printf '%s\\n' \(shellQuote(read))
          /bin/sleep \(timeoutSeconds)
        ) | \(shellQuote(codexExecutablePath)) app-server --stdio
        """
    }

    private func extractRateLimitSnapshot(from output: String) -> CodexUsageSnapshot? {
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
            return CodexRateLimitResponseMapper.map(resultData)
        }
        return nil
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
