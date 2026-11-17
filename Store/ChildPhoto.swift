import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The photo rule of the family store.
///
/// A photo of `maxPixelSize` or smaller on its long side is kept as it is, with its own bytes and format.
/// A larger photo is scaled to `maxPixelSize` on its long side, with the same aspect ratio, and encoded as JPEG.
public enum ChildPhoto {
  public static let maxPixelSize = 1024

  /// The image data to store for picked image data. Runs off the main actor, because a large photo,
  /// such as 48 megapixels, takes a while to scale.
  @concurrent
  public static func prepared(_ data: Data) async throws(FamilyStoreError) -> Data {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else { throw .unreadablePhoto }
    if max(width, height) <= maxPixelSize { return data }

    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      throw .unreadablePhoto
    }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw .unreadablePhoto }
    CGImageDestinationAddImage(
      destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw .unreadablePhoto }
    return output as Data
  }
}
