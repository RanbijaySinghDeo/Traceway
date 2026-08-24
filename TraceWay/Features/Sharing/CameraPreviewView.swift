//
//  CameraPreviewView.swift
//  TraceWay
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.updateVideoOrientation()
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        uiView.updateVideoOrientation()
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer.frame = bounds
            updateVideoOrientation()
        }

        func updateVideoOrientation() {
            guard let connection = videoPreviewLayer.connection,
                  connection.isVideoOrientationSupported
            else { return }

            let orientation = currentVideoOrientation()
            if connection.videoOrientation != orientation {
                connection.videoOrientation = orientation
            }
        }

        private func currentVideoOrientation() -> AVCaptureVideoOrientation {
            // Prefer the window scene orientation; fall back to portrait for TraceWay.
            let scene = window?.windowScene
            switch scene?.interfaceOrientation {
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .portrait, .unknown, .none:
                return .portrait
            @unknown default:
                return .portrait
            }
        }
    }
}
