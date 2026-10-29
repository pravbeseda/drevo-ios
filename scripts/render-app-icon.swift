// Renders design/app-icon.svg into the app's 1024×1024 icon: opaque, on the logo's light green, inset from the edges
// so the system's rounded mask cuts no ornament.
// Usage: swift scripts/render-app-icon.swift, from the repository root
import AppKit
import UniformTypeIdentifiers

let side = 1024
let inset = 0.1
let background = CGColor(srgbRed: 219 / 255, green: 236 / 255, blue: 219 / 255, alpha: 1)
let source = URL(fileURLWithPath: "design/app-icon.svg")
let output = URL(fileURLWithPath: "Drevo/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

guard let logo = NSImage(contentsOf: source) else { fatalError("cannot read \(source.path)") }
guard
    let context = CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fatalError("cannot create the bitmap") }

let canvas = CGRect(x: 0, y: 0, width: side, height: side)
context.setFillColor(background)
context.fill(canvas)
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
logo.draw(in: canvas.insetBy(dx: Double(side) * inset, dy: Double(side) * inset))
NSGraphicsContext.current = nil

guard let image = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("cannot write \(output.path)") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("cannot write \(output.path)") }
