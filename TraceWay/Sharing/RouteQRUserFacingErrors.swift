//
//  RouteQRUserFacingErrors.swift
//  TraceWay
//

import Foundation

/// Maps technical QR / import errors to short user-facing copy.
enum RouteQRUserFacingErrors {
    static func message(for error: Error) -> (title: String, message: String) {
        if let decoding = error as? RouteQRDecodingError {
            switch decoding {
            case .invalidFormat, .invalidPayload:
                return ("Invalid QR Code", "That QR code isn't a TraceWay route.")
            case .unsupportedVersion:
                return (
                    "Unsupported QR",
                    "This TraceWay QR code was created by a newer version of the app."
                )
            case .corruptedData, .decompressionFailed:
                return ("Unreadable QR", "This TraceWay route QR is damaged and can't be opened.")
            case .validationFailed:
                return ("Invalid Route", "This TraceWay QR doesn't contain a usable route.")
            }
        }

        if let encoding = error as? RouteQREncodingError {
            switch encoding {
            case .routeTooLarge:
                return (
                    "Route Too Large",
                    "This route contains too much GPS data to fit into a single QR code."
                )
            case .emptyRoute:
                return ("Can't Share", "This route has no GPS points to share.")
            case .compressionFailed, .encodingFailed:
                return ("Couldn't Create QR", "Something went wrong while creating the QR code. Please try again.")
            }
        }

        if let image = error as? RouteQRImageError {
            switch image {
            case .generationFailed, .emptyPayload:
                return ("Couldn't Create QR", "Something went wrong while creating the QR code. Please try again.")
            }
        }

        if let store = error as? RouteStoreError {
            switch store {
            case .emptyRoute:
                return ("Invalid Route", "This QR doesn't contain any GPS points.")
            case .tooManyPoints:
                return ("Route Too Large", "This route has too many GPS points to import.")
            case .invalidImport:
                return ("Invalid Route", "This TraceWay QR doesn't contain a usable route.")
            case .persistenceFailed:
                return ("Couldn't Save", "Couldn't save this route. Please try again.")
            }
        }

        return ("Something Went Wrong", "Please try again.")
    }
}
