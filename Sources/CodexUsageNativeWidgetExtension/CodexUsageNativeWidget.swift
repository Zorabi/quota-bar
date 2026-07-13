import CodexUsageCore
import SwiftUI
import WidgetKit

struct CodexUsageEntry: TimelineEntry {
    let date: Date
    let snapshot: CodexUsageSnapshot?
}

struct CodexUsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CodexUsageEntry {
        CodexUsageEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CodexUsageEntry) -> Void) {
        completion(CodexUsageEntry(date: Date(), snapshot: SharedUsageSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexUsageEntry>) -> Void) {
        let entry = CodexUsageEntry(date: Date(), snapshot: SharedUsageSnapshotStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct CodexUsageNativeWidgetView: View {
    let entry: CodexUsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("QuotaBar")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Text(entry.snapshot == nil ? "不可用" : "Live")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.snapshot == nil ? .orange : .green)
            }

            if let snapshot = entry.snapshot, let primary = snapshot.preferredWindow {
                Text("\(primary.remainingPercentage)%")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.13, green: 0.52, blue: 0.23))
                Text("\(primary.kind.menuLabel) remaining")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer(minLength: 2)
                HStack {
                    if let secondary = snapshot.windows.first(where: { $0.kind != primary.kind }) {
                        Text("\(secondary.kind.menuLabel) \(secondary.remainingPercentage)%")
                    }
                    Spacer()
                    Text("R \(snapshot.resetCreditsAvailable)")
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
            } else {
                Text("--")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("打开主应用刷新一次")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 0.98),
                    Color(red: 0.91, green: 0.95, blue: 0.93),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

@main
struct CodexUsageNativeWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodexUsageNativeWidget()
    }
}

struct CodexUsageNativeWidget: Widget {
    let kind = "CodexUsageNativeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CodexUsageTimelineProvider()) { entry in
            CodexUsageNativeWidgetView(entry: entry)
        }
        .configurationDisplayName("QuotaBar")
        .description("查看当前 Codex 剩余额度和可用重置次数。")
        .supportedFamilies([.systemSmall])
    }
}
