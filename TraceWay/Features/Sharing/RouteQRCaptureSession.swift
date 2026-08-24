//
//  RouteQRCaptureSession.swift
//  TraceWay
//

import AVFoundation
import Foundation

/// AVFoundation QR capture. Runs session work off the main thread.
final class RouteQRCaptureSession: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.traceway.qr.capture")
    private var isConfigured = false

    var onCodeDetected: ((String) -> Void)?

    /// Shared session for attaching a preview layer without creating a second one.
    var captureSession: AVCaptureSession { session }

    func configureIfNeeded() throws {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video) else {
            session.commitConfiguration()
            throw RouteQRCaptureError.cameraUnavailable
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            session.commitConfiguration()
            throw RouteQRCaptureError.cameraUnavailable
        }

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw RouteQRCaptureError.cameraUnavailable
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw RouteQRCaptureError.cameraUnavailable
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        if output.availableMetadataObjectTypes.contains(.qr) {
            output.metadataObjectTypes = [.qr]
        }

        session.commitConfiguration()
        isConfigured = true
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue,
              !value.isEmpty
        else { return }
        onCodeDetected?(value)
    }
}

enum RouteQRCaptureError: Error {
    case cameraUnavailable
}
