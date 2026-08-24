//
//  RouteQRErrors.swift
//  TraceWay
//

import Foundation

enum RouteQRDecodingError: Error, Equatable, LocalizedError {
    case invalidFormat
    case unsupportedVersion(Int)
    case corruptedData
    case decompressionFailed
    case invalidPayload
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "This QR code is not a valid TraceWay route."
        case let .unsupportedVersion(version):
            "This route was created with a newer version of TraceWay (v\(version)). Please update the app."
        case .corruptedData:
            "This TraceWay route QR is corrupted and cannot be opened."
        case .decompressionFailed:
            "Failed to decompress the TraceWay route data."
        case .invalidPayload:
            "The TraceWay route payload is empty or unreadable."
        case let .validationFailed(reason):
            "Invalid TraceWay route: \(reason)"
        }
    }
}

enum RouteQREncodingError: Error, Equatable, LocalizedError {
    case emptyRoute
    case compressionFailed
    case encodingFailed
    case routeTooLarge(payloadBytes: Int)

    var errorDescription: String? {
        switch self {
        case .emptyRoute:
            "Cannot share a route with no points."
        case .compressionFailed:
            "Failed to compress the route for QR sharing."
        case .encodingFailed:
            "Failed to encode the route for QR sharing."
        case let .routeTooLarge(bytes):
            "This route is too large for a single QR code (\(bytes) bytes)."
        }
    }
}

enum RouteQRImageError: Error, Equatable, LocalizedError {
    case generationFailed
    case emptyPayload

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            "Could not generate a QR code for this route."
        case .emptyPayload:
            "QR payload is empty."
        }
    }
}
