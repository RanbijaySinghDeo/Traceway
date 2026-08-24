//
//  RouteQRScannerViewModel.swift
//  TraceWay
//

import AVFoundation
import Foundation
import Observation
import UIKit

enum RouteQRScannerPhase {
    case checkingPermission
    case needsPermissionPrompt
    case permissionDenied
    case ready
    case processing
    case invalidQR(title: String, message: String)
    case imported(Route)
    case alreadyExists(Route)
    case failed(title: String, message: String)
}

@MainActor
@Observable
final class RouteQRScannerViewModel {
    private let routeStore: any RouteStoring
    private let decoder: RouteQRDecoder
    private let capture = RouteQRCaptureSession()

    var phase: RouteQRScannerPhase = .checkingPermission
    private(set) var isProcessing = false

    var previewSession: AVCaptureSession {
        capture.captureSession
    }

    init(
        routeStore: any RouteStoring,
        decoder: RouteQRDecoder = RouteQRDecoder()
    ) {
        self.routeStore = routeStore
        self.decoder = decoder
        capture.onCodeDetected = { [weak self] payload in
            Task { @MainActor in
                self?.handleDetectedPayload(payload)
            }
        }
    }

    func onAppear() {
        refreshPermissionAndStart()
    }

    func onDisappear() {
        capture.stop()
    }

    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                if granted {
                    self?.startCamera()
                } else {
                    self?.phase = .permissionDenied
                }
            }
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func resumeScanning() {
        isProcessing = false
        phase = .ready
        capture.start()
    }

    private func refreshPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCamera()
        case .notDetermined:
            phase = .needsPermissionPrompt
        case .denied, .restricted:
            phase = .permissionDenied
        @unknown default:
            phase = .permissionDenied
        }
    }

    private func startCamera() {
        do {
            try capture.configureIfNeeded()
            phase = .ready
            capture.start()
        } catch {
            phase = .failed(
                title: "Camera Unavailable",
                message: "TraceWay couldn't access the camera on this device."
            )
        }
    }

    private func handleDetectedPayload(_ payload: String) {
        guard !isProcessing else { return }
        if case .ready = phase {
            // continue
        } else {
            return
        }

        isProcessing = true
        phase = .processing
        capture.stop()

        do {
            let shared = try decoder.decode(payload)
            let result = try routeStore.importSharedRoute(shared)
            switch result {
            case let .imported(route):
                phase = .imported(route)
            case let .alreadyExists(route):
                phase = .alreadyExists(route)
            }
        } catch {
            let facing = RouteQRUserFacingErrors.message(for: error)
            if error is RouteQRDecodingError {
                phase = .invalidQR(title: facing.title, message: facing.message)
            } else {
                phase = .failed(title: facing.title, message: facing.message)
            }
            isProcessing = false
        }
    }
}
