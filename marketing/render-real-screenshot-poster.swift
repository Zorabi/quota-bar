import AppKit
import Foundation

let width: CGFloat = 1080
let height: CGFloat = 1440
let outputPath = "/Users/dongx/developer/projects/quota-bar/marketing/xiaohongshu-quota-bar-real-screenshot-poster.png"
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
        in: CGRect(x: x, y: y, width: maxWidth, height: size * 1.35),
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

func drawImage(_ image: NSImage, source: CGRect, in rect: CGRect, radius: CGFloat, shadow: NSShadow? = nil) {
    NSGraphicsContext.saveGraphicsState()
    if let shadow {
        shadow.set()
    }
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: rect, from: source, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
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

    drawImage(image, source: source, in: rect, radius: radius, shadow: shadow)
}

let canvas = NSImage(size: NSSize(width: width, height: height))
canvas.lockFocusFlipped(true)

let background = NSGradient(colors: [color(0xf8fff9), color(0xeff8f2), color(0xfff6ef)])!
background.draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: 315)

color(0xf5c9bb, 0.82).setFill()
NSBezierPath(ovalIn: CGRect(x: 828, y: 64, width: 172, height: 172)).fill()
color(0x98e6b4, 0.58).setFill()
NSBezierPath(ovalIn: CGRect(x: 2, y: 1160, width: 232, height: 232)).fill()
color(0xffe2a0, 0.76).setFill()
NSBezierPath(ovalIn: CGRect(x: 902, y: 1128, width: 100, height: 100)).fill()

rounded(CGRect(x: 72, y: 82, width: 282, height: 58), 29, fill: color(0xff5f4d))
drawText("给高频 Codex 用户", x: 72, y: 96, size: 27, weight: .heavy, color: .white, maxWidth: 282, align: .center)

drawText("把 Codex 额度", x: 72, y: 186, size: 76, weight: .black, color: color(0x16231b), maxWidth: 900)
drawText("放进菜单栏", x: 72, y: 278, size: 76, weight: .black, color: color(0x16231b), maxWidth: 900)
drawText("5h / 7d 剩多少、多久重置，一眼就知道", x: 74, y: 360, size: 32, weight: .bold, color: color(0x65736b), maxWidth: 900)

rounded(CGRect(x: 72, y: 420, width: 936, height: 885), 52, fill: color(0x13251b))
rounded(CGRect(x: 100, y: 446, width: 880, height: 56), 28, fill: color(0xeef7f1))
for (index, dotColor) in [0xff5f57, 0xffbd2e, 0x28c840].enumerated() {
    color(UInt32(dotColor)).setFill()
    NSBezierPath(ovalIn: CGRect(x: 132 + CGFloat(index) * 34, y: 464, width: 20, height: 20)).fill()
}
rounded(CGRect(x: 600, y: 460, width: 304, height: 28), 14, fill: color(0xdceade))
drawText("5h 34% | 7d 40%", x: 600, y: 462, size: 20, weight: .heavy, color: color(0x16231b), maxWidth: 304, align: .center)

if let popover = NSImage(contentsOfFile: popoverPath) {
    let popoverRect = CGRect(x: 112, y: 530, width: 490, height: 696)
    drawImageFit(popover, in: popoverRect, radius: 26, shadow: shadow(24, -20, 0.22))
    strokeRounded(popoverRect, 26, color: color(0xffffff, 0.45), lineWidth: 2)
}

if let widget = NSImage(contentsOfFile: widgetPath) {
    let widgetRect = CGRect(x: 692, y: 770, width: 244, height: 258)
    drawImageFit(widget, in: widgetRect, radius: 32, shadow: shadow(18, -16, 0.24))
    strokeRounded(widgetRect, 32, color: color(0xffffff, 0.7), lineWidth: 2)
}

rounded(CGRect(x: 666, y: 696, width: 278, height: 56), 28, fill: color(0xe3f7e8))
drawText("桌面也能常驻看", x: 666, y: 710, size: 25, weight: .black, color: color(0x178a43), maxWidth: 278, align: .center)

if let settings = NSImage(contentsOfFile: settingsPath) {
    rounded(CGRect(x: 660, y: 1050, width: 270, height: 50), 25, fill: color(0xfff0d9))
    drawText("设置页也能细调", x: 660, y: 1062, size: 23, weight: .black, color: color(0x9b5200), maxWidth: 270, align: .center)

    let settingsRect = CGRect(x: 618, y: 1112, width: 350, height: 181)
    drawImageFit(settings, in: settingsRect, radius: 24, shadow: shadow(18, -14, 0.22))
    strokeRounded(settingsRect, 24, color: color(0xffffff, 0.7), lineWidth: 2)
}

let chipY: CGFloat = 1310
let chips = [
    ("菜单栏常驻", "不用打开设置页"),
    ("自动刷新", "写代码时少分心"),
    ("只读读取", "不动账号状态"),
]
for (index, chip) in chips.enumerated() {
    let x = CGFloat(92 + index * 310)
    rounded(CGRect(x: x, y: chipY, width: 276, height: 72), 24, fill: color(0xffffff, 0.98))
    drawText(chip.0, x: x, y: chipY + 12, size: 24, weight: .black, color: color(0x16231b), maxWidth: 276, align: .center)
    drawText(chip.1, x: x, y: chipY + 43, size: 18, weight: .bold, color: color(0x65736b), maxWidth: 276, align: .center)
}

drawText("QuotaBar", x: 72, y: 1390, size: 22, weight: .black, color: color(0x178a43), maxWidth: 112)
drawText("macOS Codex 用量菜单栏工具", x: 190, y: 1390, size: 22, weight: .bold, color: color(0x65736b), maxWidth: 520)

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let representation = NSBitmapImageRep(data: tiff),
      let png = representation.representation(using: .png, properties: [:]) else {
    fatalError("无法生成 PNG")
}

try png.write(to: URL(fileURLWithPath: outputPath))
print(outputPath)
