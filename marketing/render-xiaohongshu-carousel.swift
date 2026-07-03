import AppKit
import Foundation

let canvasSize = NSSize(width: 1080, height: 1440)
let outputDir = "/Users/dongx/developer/projects/quota-bar/marketing"
let popoverPath = "/Users/dongx/developer/projects/quota-bar/marketing/assets/quota-bar-popover-clean.png"
let widgetPath = "/Users/dongx/developer/projects/quota-bar/marketing/assets/quota-bar-desktop-widget-clean.png"
let settingsPath = "/Users/dongx/developer/projects/quota-bar/marketing/assets/quota-bar-settings-clean.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

func rounded(_ rect: CGRect, _ radius: CGFloat, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func strokeRounded(_ rect: CGRect, _ radius: CGFloat, color: NSColor, lineWidth: CGFloat) {
    color.setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = lineWidth
    path.stroke()
}

func drawText(
    _ text: String,
    x: CGFloat,
    y: CGFloat,
    size: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    maxWidth: CGFloat,
    align: NSTextAlignment = .left
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    NSString(string: text).draw(
        in: CGRect(x: x, y: y, width: maxWidth, height: size * 1.4),
        withAttributes: attributes
    )
}

func shadow(_ blur: CGFloat, _ y: CGFloat, _ alpha: CGFloat) -> NSShadow {
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: y)
    shadow.shadowColor = color(0x173021, alpha)
    return shadow
}

func drawImageFit(_ image: NSImage, in rect: CGRect, radius: CGFloat, shadow: NSShadow? = nil) {
    let imageAspect = image.size.width / image.size.height
    let rectAspect = rect.width / rect.height
    var source = CGRect(origin: .zero, size: image.size)
    if imageAspect > rectAspect {
        let sourceWidth = image.size.height * rectAspect
        source.origin.x = (image.size.width - sourceWidth) / 2
        source.size.width = sourceWidth
    } else {
        let sourceHeight = image.size.width / rectAspect
        source.origin.y = (image.size.height - sourceHeight) / 2
        source.size.height = sourceHeight
    }

    NSGraphicsContext.saveGraphicsState()
    if let shadow {
        shadow.set()
    }
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: rect, from: source, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
}

func drawBackground() {
    let gradient = NSGradient(colors: [color(0xf8fff9), color(0xeff8f2), color(0xfff6ef)])!
    gradient.draw(in: CGRect(origin: .zero, size: canvasSize), angle: 315)
    color(0xf5c9bb, 0.82).setFill()
    NSBezierPath(ovalIn: CGRect(x: 828, y: 64, width: 172, height: 172)).fill()
    color(0x98e6b4, 0.52).setFill()
    NSBezierPath(ovalIn: CGRect(x: -8, y: 1168, width: 232, height: 232)).fill()
    color(0xffe2a0, 0.76).setFill()
    NSBezierPath(ovalIn: CGRect(x: 902, y: 1138, width: 100, height: 100)).fill()
}

func drawHeader(kicker: String, title1: String, title2: String, subtitle: String, index: String) {
    rounded(CGRect(x: 72, y: 82, width: 282, height: 58), 29, fill: color(0xff5f4d))
    drawText(kicker, x: 72, y: 96, size: 27, weight: .heavy, color: .white, maxWidth: 282, align: .center)
    drawText(title1, x: 72, y: 186, size: 76, weight: .black, color: color(0x16231b), maxWidth: 900)
    drawText(title2, x: 72, y: 278, size: 76, weight: .black, color: color(0x16231b), maxWidth: 900)
    drawText(subtitle, x: 74, y: 360, size: 32, weight: .bold, color: color(0x65736b), maxWidth: 900)
    drawText(index, x: 872, y: 96, size: 24, weight: .heavy, color: color(0x65736b), maxWidth: 120, align: .right)
}

func drawBrowserBar(rect: CGRect) {
    rounded(rect, 52, fill: color(0x13251b))
    rounded(CGRect(x: rect.minX + 28, y: rect.minY + 26, width: rect.width - 56, height: 56), 28, fill: color(0xeef7f1))
    for (index, dotColor) in [0xff5f57, 0xffbd2e, 0x28c840].enumerated() {
        color(UInt32(dotColor)).setFill()
        NSBezierPath(ovalIn: CGRect(x: rect.minX + 60 + CGFloat(index) * 34, y: rect.minY + 44, width: 20, height: 20)).fill()
    }
    rounded(CGRect(x: rect.minX + 528, y: rect.minY + 40, width: 304, height: 28), 14, fill: color(0xdceade))
    drawText("5h 34% | 7d 40%", x: rect.minX + 528, y: rect.minY + 42, size: 20, weight: .heavy, color: color(0x16231b), maxWidth: 304, align: .center)
}

func drawFooter(_ text: String = "QuotaBar  macOS Codex 用量菜单栏工具") {
    let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
    drawText(parts.first ?? "QuotaBar", x: 72, y: 1390, size: 22, weight: .black, color: color(0x178a43), maxWidth: 112)
    if parts.count > 1 {
        drawText(parts[1], x: 190, y: 1390, size: 22, weight: .bold, color: color(0x65736b), maxWidth: 600)
    }
}

func chip(_ title: String, _ subtitle: String, x: CGFloat, y: CGFloat, width: CGFloat = 276) {
    rounded(CGRect(x: x, y: y, width: width, height: 78), 24, fill: color(0xffffff, 0.98))
    drawText(title, x: x, y: y + 13, size: 24, weight: .black, color: color(0x16231b), maxWidth: width, align: .center)
    drawText(subtitle, x: x, y: y + 47, size: 18, weight: .bold, color: color(0x65736b), maxWidth: width, align: .center)
}

func render(_ name: String, draw: () -> Void) throws {
    let image = NSImage(size: canvasSize)
    image.lockFocusFlipped(true)
    draw()
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let representation = NSBitmapImageRep(data: tiff),
          let png = representation.representation(using: .png, properties: [:]) else {
        fatalError("无法生成 PNG")
    }

    try png.write(to: URL(fileURLWithPath: "\(outputDir)/\(name)"))
}

let popover = NSImage(contentsOfFile: popoverPath)
let widget = NSImage(contentsOfFile: widgetPath)
let settings = NSImage(contentsOfFile: settingsPath)

try render("xiaohongshu-quota-bar-carousel-01.png") {
    drawBackground()
    drawHeader(kicker: "给高频 Codex 用户", title1: "把 Codex 额度", title2: "放进菜单栏", subtitle: "5h / 7d 剩多少、多久重置，一眼就知道", index: "1/3")
    drawBrowserBar(rect: CGRect(x: 72, y: 420, width: 936, height: 820))
    if let popover {
        let rect = CGRect(x: 295, y: 532, width: 490, height: 696)
        drawImageFit(popover, in: rect, radius: 34, shadow: shadow(28, -22, 0.24))
        strokeRounded(rect, 34, color: color(0xffffff, 0.5), lineWidth: 2)
    }
    chip("菜单栏常驻", "不用打开设置页", x: 92, y: 1290)
    chip("自动刷新", "写代码时少分心", x: 402, y: 1290)
    chip("只读读取", "不动账号状态", x: 712, y: 1290)
    drawFooter()
}

try render("xiaohongshu-quota-bar-carousel-02.png") {
    drawBackground()
    drawHeader(kicker: "桌面小组件", title1: "写代码时", title2: "瞄一眼就够", subtitle: "把用量固定在桌面，不打断当前工作流", index: "2/3")
    rounded(CGRect(x: 72, y: 430, width: 936, height: 760), 52, fill: color(0x13251b))
    if let widget {
        let rect = CGRect(x: 237, y: 520, width: 606, height: 640)
        drawImageFit(widget, in: rect, radius: 44, shadow: shadow(30, -24, 0.24))
        strokeRounded(rect, 44, color: color(0xffffff, 0.55), lineWidth: 2)
    }
    chip("5h 主数字", "当前窗口先看它", x: 92, y: 1312)
    chip("7d 也展示", "长期节奏不丢", x: 402, y: 1312)
    chip("账户信息", "Plan / Credits", x: 712, y: 1312)
    drawFooter()
}

try render("xiaohongshu-quota-bar-carousel-03.png") {
    drawBackground()
    drawHeader(kicker: "设置细节", title1: "显示方式", title2: "自己调", subtitle: "刷新间隔、信息丰富度、状态栏密度都能改", index: "3/3")
    rounded(CGRect(x: 72, y: 430, width: 936, height: 760), 52, fill: color(0x13251b))
    if let settings {
        let rect = CGRect(x: 108, y: 610, width: 864, height: 446)
        drawImageFit(settings, in: rect, radius: 30, shadow: shadow(28, -22, 0.24))
        strokeRounded(rect, 30, color: color(0xffffff, 0.5), lineWidth: 2)
    }
    chip("刷新间隔", "1 / 5 / 15 / 30 分钟", x: 92, y: 1298)
    chip("信息密度", "简洁 / 标准 / 丰富", x: 402, y: 1298)
    chip("状态栏长度", "极简 / 紧凑 / 详细", x: 712, y: 1298)
    drawFooter()
}

print("生成完成：xiaohongshu-quota-bar-carousel-01.png ... 03.png")
