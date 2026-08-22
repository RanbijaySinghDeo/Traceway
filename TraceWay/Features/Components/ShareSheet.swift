//
//  ShareSheet.swift
//  TraceWay
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    let routeName: String
    var onComplete: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let item = GPXActivityItemSource(fileURL: fileURL, routeName: routeName)
        var items: [Any] = [item, fileURL]

        // XML twin improves visibility in WhatsApp / document share destinations.
        let xmlURL = fileURL.deletingPathExtension().appendingPathExtension("xml")
        if FileManager.default.fileExists(atPath: xmlURL.path) {
            items.append(xmlURL)
        }

        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
