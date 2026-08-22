//
//  RouteExporter.swift
//  TraceWay
//

import Foundation

protocol RouteExporting: Sendable {
    func makeGPX(name: String, points: [LocationPoint], createdAt: Date) throws -> Data
    func writeTemporaryGPXFile(name: String, points: [LocationPoint], createdAt: Date) throws -> URL
}

enum RouteExporterError: Error, LocalizedError, Equatable {
    case emptyRoute
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .emptyRoute:
            "Cannot export a route with no points."
        case .encodingFailed:
            "Failed to encode GPX data."
        }
    }
}

/// Builds GPX 1.1 track files from the recorded GPS path (no simplification).
struct RouteExporter: RouteExporting {
    func makeGPX(name: String, points: [LocationPoint], createdAt: Date = .now) throws -> Data {
        guard !points.isEmpty else {
            throw RouteExporterError.emptyRoute
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var body = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="TraceWay" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(xmlEscape(name))</name>
            <time>\(iso.string(from: createdAt))</time>
          </metadata>
          <trk>
            <name>\(xmlEscape(name))</name>
            <trkseg>

        """

        for point in points {
            body += "      <trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\">\n"
            if let altitude = point.altitude {
                body += "        <ele>\(altitude)</ele>\n"
            }
            body += "        <time>\(iso.string(from: point.timestamp))</time>\n"
            body += "      </trkpt>\n"
        }

        body += """
            </trkseg>
          </trk>
        </gpx>
        """

        guard let data = body.data(using: .utf8) else {
            throw RouteExporterError.encodingFailed
        }
        return data
    }

    func writeTemporaryGPXFile(name: String, points: [LocationPoint], createdAt: Date = .now) throws -> URL {
        let data = try makeGPX(name: name, points: points, createdAt: createdAt)
        let safeName = sanitizeFilename(name)

        // Use Caches (not tmp) so other apps can read the file via the share sheet.
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TraceWayShares", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // Clear previous exports to avoid clutter.
        if let existing = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) {
            for file in existing {
                try? FileManager.default.removeItem(at: file)
            }
        }

        let url = folder.appendingPathComponent("\(safeName).gpx")
        try data.write(to: url, options: .atomic)

        // Also write an XML twin — some apps (including WhatsApp) list XML/documents more reliably.
        let xmlURL = folder.appendingPathComponent("\(safeName).xml")
        try data.write(to: xmlURL, options: .atomic)

        // Prefer .gpx for mapping apps; ShareSheet also receives the activity item source.
        return url
    }

    private func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "TraceWay-Route" : trimmed
    }
}
