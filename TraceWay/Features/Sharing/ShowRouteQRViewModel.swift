//
//  ShowRouteQRViewModel.swift
//  TraceWay
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class ShowRouteQRViewModel {
    let route: Route

    var qrImage: UIImage?
    /// Branded card used for the system share sheet (QR + caption burned into the image).
    var shareImage: UIImage?
    var errorTitle: String?
    var errorMessage: String?
    var isGenerating = false
    var lastPayloadBytes: Int?

    /// Set only when the full track did not fit and a simplified path was encoded.
    var simplificationNote: String?

    private let preferredCorrection: RouteQRErrorCorrectionLevel

    init(
        route: Route,
        preferredCorrection: RouteQRErrorCorrectionLevel = .q
    ) {
        self.route = route
        self.preferredCorrection = preferredCorrection
    }

    var sharedRoute: TraceWaySharedRoute {
        TraceWaySharedRoute.from(route: route)
    }

    func generate() {
        isGenerating = true
        defer { isGenerating = false }
        lastPayloadBytes = nil
        simplificationNote = nil
        qrImage = nil
        shareImage = nil
        errorTitle = nil
        errorMessage = nil

        let full = sharedRoute
        let pointCount = full.points.count

        // 1) Prefer the exact track — short / fitting routes are never simplified.
        switch attemptEncode(full) {
        case let .success(payload):
            commitSuccess(payload: payload, simplified: nil)
            return
        case .failed:
            return
        case .tooLarge:
            break
        }

        // 2) Only for oversized routes: simplify for QR (local SwiftData track unchanged).
        let simplified = RouteQRPathSimplifier.simplifyForQR(full)
        switch attemptEncode(simplified.route) {
        case let .success(payload):
            commitSuccess(payload: payload, simplified: simplified)
            return
        case .failed:
            return
        case .tooLarge:
            errorTitle = "Route Too Large"
            errorMessage = """
            This route (\(pointCount) points) is still too large for a single QR code even after simplifying \
            to \(simplified.simplifiedPointCount) points. Export GPX to share the full track.
            """
        }
    }

    // MARK: - Private

    private enum EncodeAttempt {
        case success(String)
        case tooLarge
        case failed
    }

    private func commitSuccess(payload: String, simplified: RouteQRPathSimplifier.SimplificationResult?) {
        lastPayloadBytes = payload.lengthOfBytes(using: .utf8)
        if let simplified, simplified.didSimplify {
            simplificationNote = """
            Simplified for QR (\(simplified.simplifiedPointCount) of \(simplified.originalPointCount) points). \
            Full detail stays on this device — use Export GPX for the exact dense track.
            """
        } else {
            simplificationNote = nil
        }
        errorTitle = nil
        errorMessage = nil
        rebuildShareCard()
    }

    private func rebuildShareCard() {
        guard let qrImage else {
            shareImage = nil
            return
        }
        shareImage = RouteQRShareCardRenderer.makeShareImage(
            qrImage: qrImage,
            routeName: route.name,
            distanceMeters: route.distanceMeters,
            durationSeconds: route.durationSeconds
        )
    }

    private func attemptEncode(_ shared: TraceWaySharedRoute) -> EncodeAttempt {
        let levels: [RouteQRErrorCorrectionLevel] = {
            switch preferredCorrection {
            case .q: [.q, .m, .l]
            case .m: [.m, .l]
            case .h: [.h, .q, .m, .l]
            case .l: [.l]
            }
        }()

        var sawTooLarge = false

        for level in levels {
            do {
                let encoder = RouteQREncoder(
                    strategy: .compactMicrodegreeDeltas,
                    enforceSingleQRCapacity: true,
                    errorCorrectionLevel: level
                )
                let payload = try encoder.encode(shared)
                let renderer = RouteQRImageRenderer(correctionLevel: level, dimension: 1024)
                qrImage = try renderer.makeImage(payload: payload)
                return .success(payload)
            } catch let error as RouteQREncodingError {
                switch error {
                case .routeTooLarge:
                    sawTooLarge = true
                    continue
                case .emptyRoute, .compressionFailed, .encodingFailed:
                    let facing = RouteQRUserFacingErrors.message(for: error)
                    errorTitle = facing.title
                    errorMessage = facing.message + " (\(shared.points.count) points)"
                    return .failed
                }
            } catch {
                // Image generation failed — try a lower EC level.
                continue
            }
        }

        return sawTooLarge ? .tooLarge : .failed
    }
}
