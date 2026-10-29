// Renders design/app-icon.svg into the app's images: the 1024×1024 icon, opaque, on the logo's light green, inset from
// the edges so the system's rounded mask cuts no ornament; and the launch screen's 160 pt logo, transparent.
// Usage: swift scripts/render-app-icon.swift, from the repository root
import AppKit
import UniformTypeIdentifiers

let lightGreen = CGColor(srgbRed: 219 / 255, green: 236 / 255, blue: 219 / 255, alpha: 1)
let launchLogoPoints = 160
let assets = "Drevo/Assets.xcassets"

guard let logo = NSImage(contentsOf: URL(fileURLWithPath: "design/app-icon.svg")) else {
    fatalError("cannot read design/app-icon.svg")
}

func render(side: Int, inset: Double, background: CGColor?, to path: String) {
    let alpha = background == nil ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast
    guard
        let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue)
    else { fatalError("cannot create the bitmap for \(path)") }
    let canvas = CGRect(x: 0, y: 0, width: side, height: side)
    if let background {
        context.setFillColor(background)
        context.fill(canvas)
    }
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    logo.draw(in: canvas.insetBy(dx: Double(side) * inset, dy: Double(side) * inset))
    NSGraphicsContext.current = nil

    let url = URL(fileURLWithPath: path)
    guard let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("cannot write \(path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("cannot write \(path)") }
}

render(side: 1024, inset: 0.1, background: lightGreen, to: "\(assets)/AppIcon.appiconset/AppIcon.png")
for scale in [2, 3] {
    render(
        side: launchLogoPoints * scale, inset: 0, background: nil,
        to: "\(assets)/LaunchLogo.imageset/LaunchLogo@\(scale)x.png")
}
