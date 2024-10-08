import SwiftUI
import CoreImage.CIFilterBuiltins

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage

#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

/// Generate a QR Code as Image
func generateQRCode(from string: String, size: CGFloat = 200) -> PlatformImage {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()

    let data = Data(string.utf8)
    filter.setValue(data, forKey: "inputMessage")
    let ciImage = filter.outputImage!

    let transform = CGAffineTransform(scaleX: size / ciImage.extent.size.width, y: size / ciImage.extent.size.height)
    let scaledCIImage = ciImage.transformed(by: transform)

    let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent)!

    #if canImport(UIKit)
    return UIImage(cgImage: cgImage)

    #elseif canImport(AppKit)
    return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    #endif
}
