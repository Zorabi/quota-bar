import AppKit
import CodexUsageCore
import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text(model.menuBarTitle)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
    }
}

struct StatusPopoverView: View {
    @ObservedObject var model: AppModel
    let onToggleWidget: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HeaderStrip(model: model)

            if let snapshot = model.snapshot {
                PrimaryUsageBlock(snapshot: snapshot)
                if model.settings.detailLevel != .concise {
                    WindowBars(snapshot: snapshot, resetStyle: model.settings.detailLevel == .standard ? .dateOnly : .countdownAndDate)
                }
                if model.settings.detailLevel == .rich {
                    AccountStrip(snapshot: snapshot)
                }
                RefreshStatusStrip(model: model)
            } else {
                UnavailableBlock()
            }

            HStack(spacing: 8) {
                CompactActionButton(title: "桌面小组件", prominence: .secondary, action: onToggleWidget)
                CompactActionButton(title: "设置", prominence: .secondary, action: onOpenSettings)
                CompactActionButton(title: model.isRefreshing ? "刷新中" : "刷新", prominence: .secondary) {
                    model.refresh()
                }
                .disabled(model.isRefreshing)
            }
        }
        .padding(16)
        .frame(width: 356)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.99, blue: 0.98),
                        Color(red: 0.92, green: 0.95, blue: 0.94),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Color.white.opacity(0.34)
            }
        )
    }
}

struct SettingsPanelView: View {
    @ObservedObject var model: AppModel
    let onToggleWidget: () -> Void

    init(model: AppModel, onToggleWidget: @escaping () -> Void = {}) {
        self.model = model
        self.onToggleWidget = onToggleWidget
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("QuotaBar 设置")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("调整状态栏显示、刷新频率和详情密度。真实用量来自 Codex app-server 只读接口。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                }

                RefreshStatusStrip(model: model)
                SettingsActionStrip(model: model)

                SettingsRow(title: "刷新间隔", detail: "多久重新读取一次当前账号用量") {
                    Picker("", selection: $model.settings.refreshIntervalMinutes) {
                        ForEach([1, 5, 15, 30], id: \.self) { minutes in
                            Text("\(minutes) 分钟").tag(minutes)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SettingsRow(title: "信息丰富度", detail: "影响详情视图里的辅助信息数量") {
                        Picker("", selection: $model.settings.detailLevel) {
                            ForEach(DetailLevel.allCases, id: \.self) { level in
                                Text(level.displayText).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 230)
                    }
                    DetailPreviewCard(model: model)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SettingsRow(title: "状态栏", detail: "控制菜单栏文本长度") {
                        Picker("", selection: $model.settings.menuBarDensity) {
                            ForEach(MenuBarDensity.allCases, id: \.self) { density in
                                Text(density.displayText).tag(density)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 230)
                    }
                    SettingsPreviewCard(model: model)
                }

                SettingsRow(title: "Codex 字样", detail: "控制状态栏是否显示 Codex 前缀") {
                    Toggle("", isOn: $model.settings.showsCodexPrefix)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                SettingsRow(title: "桌面小组件", detail: "显示 App 内悬浮小组件；原生系统小组件请在 macOS 小组件库中添加") {
                    HStack(spacing: 10) {
                        Button("显示/隐藏") {
                            onToggleWidget()
                        }
                    }
                }

                SettingsRow(title: "吸附桌面", detail: "将 App 内悬浮小组件放到桌面层级；可与原生桌面组件共存") {
                    Toggle("", isOn: $model.settings.pinsWidgetToDesktop)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                SettingsRow(title: "原生桌面组件", detail: "先把 App 放入 /Applications 并打开一次，再右键桌面选择“编辑小组件”，搜索 QuotaBar。") {
                    HStack(spacing: 8) {
                        InstallToApplicationsButton()
                        Button("显示位置") {
                            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                        }
                    }
                }

                ExitAppSection()
            }
            .padding(24)
        }
        .frame(width: 620, height: 720, alignment: .topLeading)
        .background(Color(red: 0.96, green: 0.97, blue: 0.96))
    }
}

struct DesktopWidgetView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderStrip(model: model)

            if let snapshot = model.snapshot {
                PrimaryUsageBlock(snapshot: snapshot)
                WindowBars(snapshot: snapshot, resetStyle: .countdownAndDate)
                AccountStrip(snapshot: snapshot)
            } else {
                UnavailableBlock()
            }
        }
        .padding(20)
        .frame(width: 376)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.18))
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.96, green: 0.98, blue: 0.97).opacity(0.97))
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(0.22)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }
}

private struct HeaderStrip: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("QuotaBar")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(model.snapshot == nil ? "Codex 用量未连接" : "Codex 用量 · 只读")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.46))
            }
            Spacer()
            FreshnessBadge(snapshot: model.snapshot)
        }
    }
}

private struct PrimaryUsageBlock: View {
    let snapshot: CodexUsageSnapshot

    var body: some View {
        let primary = snapshot.window(.fiveHour)
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            Text(primary.map { "\($0.remainingPercentage)%" } ?? "--")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(red: 0.13, green: 0.52, blue: 0.23))
            Text("5h remaining")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.25, green: 0.29, blue: 0.28))
            Spacer()
        }
    }
}

private struct WindowBars: View {
    let snapshot: CodexUsageSnapshot
    let resetStyle: ResetMetadataStyle

    var body: some View {
        VStack(spacing: 12) {
            UsageBar(window: snapshot.window(.fiveHour), resetStyle: resetStyle)
            UsageBar(window: snapshot.window(.sevenDay), resetStyle: resetStyle)
        }
        .padding(12)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct UsageBar: View {
    let window: UsageWindowSnapshot?
    let resetStyle: ResetMetadataStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(window?.kind.displayTitle ?? "额度窗口")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Spacer()
                Text(window.map { "\($0.remainingPercentage)% remaining" } ?? "--")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.13, green: 0.52, blue: 0.23))
            }

            ProgressView(value: Double(window?.remainingPercentage ?? 0), total: 100)
                .tint(Color(red: 0.16, green: 0.56, blue: 0.25))

            HStack {
                Text("\(window?.usedPercentage ?? 0)% used")
                    .lineLimit(1)
                Spacer()
                if let window {
                    Text(resetStyle.text(for: window))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Resets --:--")
                        .lineLimit(1)
                }
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color(red: 0.43, green: 0.49, blue: 0.47))
            .monospacedDigit()
        }
    }
}

private enum ResetMetadataStyle {
    case dateOnly
    case countdownAndDate

    func text(for window: UsageWindowSnapshot) -> String {
        switch self {
        case .dateOnly:
            return "Resets \(window.resetDateText())"
        case .countdownAndDate:
            return "Resets \(window.readableResetCountdownText) · \(window.resetDateText())"
        }
    }
}

private struct AccountStrip: View {
    let snapshot: CodexUsageSnapshot

    var body: some View {
        HStack(spacing: 10) {
            InfoTile(title: "Plan", value: snapshot.planName)
            InfoTile(title: "Credits", value: "\(snapshot.credits)")
            InfoTile(title: "Reset credits", value: "\(snapshot.resetCreditsAvailable)")
        }
    }
}

private struct SettingsPreviewCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("状态栏预览")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            Text(model.menuBarTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DetailPreviewCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("丰富度预览")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                Spacer()
                Text(model.settings.detailLevel.displayText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.13, green: 0.52, blue: 0.23))
            }

            if let snapshot = model.snapshot {
                PrimaryUsageBlock(snapshot: snapshot)
                    .scaleEffect(0.82, anchor: .leading)
                    .frame(height: 42, alignment: .leading)
                if model.settings.detailLevel != .concise {
                    WindowBars(snapshot: snapshot, resetStyle: model.settings.detailLevel == .standard ? .dateOnly : .countdownAndDate)
                }
                if model.settings.detailLevel == .rich {
                    AccountStrip(snapshot: snapshot)
                }
            } else {
                Text("刷新一次后显示预览")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.60), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SettingsActionStrip: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Button(model.isRefreshing ? "刷新中..." : "刷新当前用量") {
                model.refresh()
            }
            .disabled(model.isRefreshing)
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Spacer()

            Text(model.snapshot == nil ? "当前未连接" : "已连接当前账号")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(model.snapshot == nil ? .orange : .green)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ExitAppSection: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("退出应用")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("关闭状态栏、悬浮小组件和后台刷新。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
            Spacer()
            Button("退出 QuotaBar") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(14)
        .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct RefreshStatusStrip: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.13, green: 0.52, blue: 0.23).opacity(0.12))
                    Image(systemName: model.isRefreshing ? "arrow.triangle.2.circlepath" : "clock")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.13, green: 0.52, blue: 0.23))
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.isRefreshing ? "正在刷新" : "自动刷新")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.24, green: 0.29, blue: 0.27))
                    Text("每 \(model.settings.refreshIntervalMinutes) 分钟")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.43, green: 0.49, blue: 0.47))
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(model.isRefreshing ? "读取中" : "距下次 \(RefreshScheduleFormatter.remainingText(until: model.nextRefreshAt, now: timeline.date))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.13, green: 0.52, blue: 0.23))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text("上次 \(RefreshScheduleFormatter.clockText(model.lastRefreshedAt))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.43, green: 0.49, blue: 0.47))
                        .monospacedDigit()
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 300, alignment: .leading)
            Spacer()
            control
        }
        .padding(14)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct InstallToApplicationsButton: View {
    @State private var message: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button("安装到 /Applications") {
                install()
            }
            if let message {
                Text(message)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func install() {
        let source = Bundle.main.bundleURL
        let destination = URL(fileURLWithPath: "/Applications/QuotaBar.app")

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            let registered = registerNativeWidget(in: destination)
            message = registered ? "已安装，搜索 QuotaBar 添加小组件" : "已安装；小组件可能需要正式签名"
        } catch {
            message = "安装失败，请手动拖入 /Applications"
        }
    }

    private func registerNativeWidget(in appURL: URL) -> Bool {
        let extensionURL = appURL.appendingPathComponent("Contents/PlugIns/CodexUsageNativeWidgetExtension.appex")
        let launchServices = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        _ = runTool(launchServices, arguments: ["-f", appURL.path])

        let added = runTool("/usr/bin/pluginkit", arguments: ["-a", extensionURL.path])
        let enabled = runTool("/usr/bin/pluginkit", arguments: ["-e", "use", "-i", "dev.quotabar.codex.native-widget"])
        return added && enabled
    }

    private func runTool(_ path: String, arguments: [String]) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

private enum ButtonProminence {
    case primary
    case secondary
}

private struct CompactActionButton: View {
    let title: String
    let prominence: ButtonProminence
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .focusable(false)
        .frame(maxWidth: .infinity)
        .buttonStyle(CompactActionButtonStyle(prominence: prominence))
    }
}

private struct CompactActionButtonStyle: ButtonStyle {
    let prominence: ButtonProminence

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(backgroundColor(configuration: configuration), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor(configuration: configuration), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }

    private var foregroundColor: Color {
        prominence == .primary ? .white : Color(red: 0.20, green: 0.24, blue: 0.23)
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        if prominence == .primary {
            return configuration.isPressed ? Color(red: 0.10, green: 0.42, blue: 0.19) : Color(red: 0.13, green: 0.52, blue: 0.23)
        }
        return configuration.isPressed ? Color(red: 0.85, green: 0.95, blue: 0.88) : Color.white.opacity(0.62)
    }

    private func borderColor(configuration: Configuration) -> Color {
        configuration.isPressed ? Color(red: 0.13, green: 0.52, blue: 0.23).opacity(0.28) : Color.white.opacity(0.24)
    }
}

private struct UnavailableBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("未连接当前账号")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("无法从 Codex app-server 读取只读额度接口。请确认 Codex 已登录，然后点击刷新。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.43, green: 0.49, blue: 0.47))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct FreshnessBadge: View {
    let snapshot: CodexUsageSnapshot?

    var body: some View {
        Text(snapshot?.freshness.displayText ?? "不可用")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(snapshot == nil ? Color.orange : Color(red: 0.13, green: 0.52, blue: 0.23))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background((snapshot == nil ? Color.orange : Color.green).opacity(0.14), in: Capsule())
    }
}

private struct MiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.43, green: 0.49, blue: 0.47))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InfoTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.43, green: 0.49, blue: 0.47))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
