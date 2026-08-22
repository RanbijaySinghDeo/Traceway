//
//  GPXActivityItemSource.swift
//  TraceWay
//

import LinkPresentation
import UniformTypeIdentifiers
import UIKit

/// Makes GPX files more visible to share destinations (WhatsApp, Files, Mail, etc.).
final class GPXActivityItemSource: NSObject, UIActivityItemSource {
    let fileURL: URL
    let routeName: String

    init(fileURL: URL, routeName: String) {
        self.fileURL = fileURL
        self.routeName = routeName
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        routeName
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.xml.identifier
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = routeName
        metadata.originalURL = fileURL
        metadata.url = fileURL
        return metadata
    }
}
