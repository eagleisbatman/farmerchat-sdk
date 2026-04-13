import Foundation
import ImageIO
import CoreLocation

/// Utilities for extracting metadata from images.
/// No location permission is required — GPS data is read from EXIF embedded in the image file.
internal enum ImageProcessor {

    /// Extracts GPS coordinates from the EXIF metadata of the image at [url].
    ///
    /// - Returns: (latitude, longitude) formatted to 6 decimal places,
    ///            or nil if the image has no GPS EXIF data.
    static func extractGPS(from url: URL) -> (latitude: String, longitude: String)? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let props  = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
            let gps    = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
            let lat    = gps[kCGImagePropertyGPSLatitude  as String] as? Double,
            let lon    = gps[kCGImagePropertyGPSLongitude as String] as? Double
        else { return nil }

        let latRef = gps[kCGImagePropertyGPSLatitudeRef  as String] as? String ?? "N"
        let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"

        let finalLat = latRef == "S" ? -lat : lat
        let finalLon = lonRef == "W" ? -lon : lon

        return (
            String(format: "%.6f", finalLat),
            String(format: "%.6f", finalLon)
        )
    }
}
