// Deterministic icon packaging. Keep the original artwork immutable so repeated
// builds cannot accumulate padding or resize an already resized foreground.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
let source = URL(fileURLWithPath: "docs/design/icon-source/CampusMark-original.png")
let original = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(source as CFURL, nil)!, 0, nil)!
// Alpha >= 16 artwork bounds in the source: exclude near-transparent generation
// noise. Crop to the full visible mark, preserving the gear, flame and petals.
let artwork = original.cropping(to: CGRect(x: 164, y: 56, width: 976, height: 1165))!
let size = 1024
let height: CGFloat = 800 // 78.125%: equal 112px top/bottom optical clearance.
let width = height * CGFloat(artwork.width) / CGFloat(artwork.height)
let rect = CGRect(x: (1024 - width) / 2, y: (1024 - height) / 2, width: width, height: height)
func canvas(alpha: Bool) -> CGContext {
    let result = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (alpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue)!
    result.interpolationQuality = .high
    return result
}
func write(_ image: CGImage, _ path: String) {
    let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
        UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination))
}
let foreground = canvas(alpha: true)
foreground.draw(artwork, in: rect)
for path in [
    "GTIIT/Resources/AppIcon.icon/Assets/CampusDraft.png",
    "docs/design/AppIcon.icon/Assets/CampusDraft.png",
    "GTIIT/Resources/Assets.xcassets/CampusMark.imageset/CampusMark.png"
] { write(foreground.makeImage()!, path) }
for (name, color) in [("AppIcon", [0.71, 0.89, 0.98]), ("AppIconDark", [0.028, 0.118, 0.275])] {
    let context = canvas(alpha: false)
    context.setFillColor(CGColor(red: color[0], green: color[1], blue: color[2], alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    context.draw(artwork, in: rect)
    write(context.makeImage()!, "GTIIT/Resources/Assets.xcassets/AppIcon.appiconset/\(name).png")
}
print("Normalized icon: 800px visible height, 112px vertical inset; native, About and light/dark fallbacks synchronized")
