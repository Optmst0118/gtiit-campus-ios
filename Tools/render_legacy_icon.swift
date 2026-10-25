// Mechanical asset compilation: one generated transparent foreground, two
// opaque system appearance backgrounds; square canvases retain the OS mask.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
let source = URL(fileURLWithPath: "GTIIT/Resources/AppIcon.icon/Assets/CampusDraft.png")
let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(source as CFURL, nil)!, 0, nil)!
for (name, color) in [("AppIcon", [0.71, 0.89, 0.98]), ("AppIconDark", [0.028, 0.118, 0.275])] {
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(red: color[0], green: color[1], blue: color[2], alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let target = URL(fileURLWithPath: "GTIIT/Resources/Assets.xcassets/AppIcon.appiconset/\(name).png")
    let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
}
print("Light/dark opaque 1024px fallbacks compiled")
