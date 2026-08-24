//
//  ImageShareSheet.swift
//  TraceWay
//

import SwiftUI
import UIKit

/// Native share sheet for a QR (or other) image.
struct ImageShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    var onComplete: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
