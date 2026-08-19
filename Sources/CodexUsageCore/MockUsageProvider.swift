public struct MockUsageProvider: UsageProviding {
    public init() {}

    public func fetchUsage() -> Result<CodexUsageSnapshot, UsageProviderError> {
        .success(
            CodexUsageSnapshot(
                windows: [
                    UsageWindowSnapshot(kind: .fiveHour, remainingPercentage: 52, resetsIn: 8_820),
                    UsageWindowSnapshot(kind: .sevenDay, remainingPercentage: 42, resetsIn: 345_600),
                ],
                planName: "Plus",
                credits: 0,
                resetCreditsAvailable: 3,
                freshness: .live
            )
        )
    }
}
