// Mechanical asset packaging: opaque square fallback, no manual corner mask.
// The primary iOS 26+ icon is AppIcon.icon rendered by Apple's asset compiler.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let source = URL(fileURLWithPath: "GTIIT/Resources/AppIcon.icon/Assets/CampusDraft.png")
let target = URL(fileURLWithPath: "GTIIT/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(source as CFURL, nil)!, 0, nil)!
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.93, green: 0.975, blue: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
print("Opaque 1024px fallback compiled")
