//
//  RouteQRImageRenderer.swift
//  TraceWay
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

enum RouteQRErrorCorrectionLevel: String, Sendable, CaseIterable {
    case l = "L"
    case m = "M"
    case q = "Q"
    case h = "H"

    /// ISO/IEC 18004 byte-mode capacities for Version 40.
    var maxByteCapacityVersion40: Int {
        switch self {
        case .l: 2_953
        case .m: 2_331
        case .q: 1_663
        case .h: 1_273
        }
    }
}

struct RouteQRImageRenderer: Sendable {
    var correctionLevel: RouteQRErrorCorrectionLevel
    /// Output pixel size for the QR bitmap (square).
    var dimension: CGFloat

    init(correctionLevel: RouteQRErrorCorrectionLevel = .q, dimension: CGFloat = 1024) {
        self.correctionLevel = correctionLevel
        self.dimension = dimension
    }

    func makeImage(payload: String) throws -> UIImage {
        let ciImage = try makeCIImage(payload: payload)
        let scaled = try scaledImage(ciImage, dimension: dimension)

        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            throw RouteQRImageError.generationFailed
        }
        return UIImage(cgImage: cgImage)
    }

    func makeCIImage(payload: String) throws -> CIImage {
        guard !payload.isEmpty else {
            throw RouteQRImageError.emptyPayload
        }
        guard let data = payload.data(using: .utf8) else {
            throw RouteQRImageError.generationFailed
        }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = correctionLevel.rawValue

        guard let output = filter.outputImage else {
            throw RouteQRImageError.generationFailed
        }
        // Empty/near-empty extent typically means the payload exceeded QR capacity.
        guard output.extent.width > 2, output.extent.height > 2 else {
            throw RouteQRImageError.generationFailed
        }
        return output
    }

    private func scaledImage(_ image: CIImage, dimension: CGFloat) throws -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            throw RouteQRImageError.generationFailed
        }
        let scale = dimension / extent.width
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
}

/// ISO/IEC 18004 approximate byte capacities by version (byte mode).
enum RouteQRCapacityTable {
    static func minimumVersion(byteCount: Int, level: RouteQRErrorCorrectionLevel) -> Int? {
        for version in 1...40 {
            if byteCapacity(version: version, level: level) >= byteCount {
                return version
            }
        }
        return nil
    }

    static func byteCapacity(version: Int, level: RouteQRErrorCorrectionLevel) -> Int {
        // Representative capacities (byte mode). Source: ISO/IEC 18004 tables.
        let table: [RouteQRErrorCorrectionLevel: [Int]] = [
            .l: [
                17, 32, 53, 78, 106, 134, 154, 192, 230, 271,
                321, 367, 425, 458, 520, 586, 644, 718, 792, 858,
                929, 1003, 1091, 1171, 1273, 1367, 1465, 1528, 1628, 1732,
                1840, 1952, 2068, 2188, 2303, 2431, 2563, 2699, 2809, 2953
            ],
            .m: [
                14, 26, 42, 62, 84, 106, 122, 152, 180, 213,
                251, 287, 331, 362, 412, 450, 504, 560, 624, 666,
                711, 779, 857, 911, 997, 1059, 1125, 1190, 1264, 1370,
                1452, 1542, 1632, 1722, 1812, 1914, 1992, 2102, 2216, 2331
            ],
            .q: [
                11, 20, 32, 46, 60, 74, 86, 108, 130, 151,
                177, 203, 241, 258, 292, 322, 364, 394, 442, 482,
                509, 565, 611, 661, 715, 751, 805, 868, 908, 982,
                1030, 1112, 1168, 1228, 1283, 1351, 1423, 1499, 1579, 1663
            ],
            .h: [
                7, 14, 24, 34, 44, 58, 64, 84, 98, 119,
                137, 155, 177, 194, 220, 250, 280, 310, 338, 382,
                403, 439, 461, 511, 535, 573, 625, 658, 698, 742,
                790, 842, 898, 958, 983, 1051, 1093, 1139, 1219, 1273
            ]
        ]
        let values = table[level] ?? []
        let index = max(0, min(version, values.count) - 1)
        return values[index]
    }
}
