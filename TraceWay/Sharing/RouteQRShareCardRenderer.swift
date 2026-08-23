//
//  RouteQRShareCardRenderer.swift
//  TraceWay
//

import UIKit

/// Builds a branded share image: QR + route title + scan instructions.
/// A single composite image shares reliably via WhatsApp / Messages / AirDrop.
enum RouteQRShareCardRenderer {
    static func makeShareImage(
        qrImage: UIImage,
        routeName: String,
        distanceMeters: Double,
        durationSeconds: TimeInterval
    ) -> UIImage {
        let width: CGFloat = 1080
        let horizontalPadding: CGFloat = 72
        let topPadding: CGFloat = 72
        let qrSide: CGFloat = 720
        let spacingAfterQR: CGFloat = 56
        let bottomPadding: CGFloat = 72

        let distanceText = TraceWayFormatters.distance(distanceMeters)
        let durationText = TraceWayFormatters.duration(durationSeconds)
        let statsText = "\(distanceText) · \(durationText)"
        let eyebrow = "📍 TraceWay Route"
        let instruction = "Scan this QR code with TraceWay to receive\nthe exact route."

        let contentWidth = width - horizontalPadding * 2

        let eyebrowFont = UIFont.systemFont(ofSize: 34, weight: .semibold)
        let titleFont = UIFont.systemFont(ofSize: 48, weight: .bold)
        let statsFont = UIFont.systemFont(ofSize: 36, weight: .semibold)
        let instructionFont = UIFont.systemFont(ofSize: 32, weight: .regular)

        let eyebrowHeight = height(of: eyebrow, font: eyebrowFont, width: contentWidth)
        let titleHeight = height(of: routeName, font: titleFont, width: contentWidth)
        let statsHeight = height(of: statsText, font: statsFont, width: contentWidth)
        let instructionHeight = height(of: instruction, font: instructionFont, width: contentWidth)

        let height =
            topPadding
            + qrSide
            + spacingAfterQR
            + eyebrowHeight
            + 12
            + titleHeight
            + 10
            + statsHeight
            + 28
            + instructionHeight
            + bottomPadding

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)

        return renderer.image { context in
            let cg = context.cgContext

            // Soft charcoal card background (matches TraceWay, stays readable in chats).
            UIColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // White QR plate for scan contrast.
            let qrPlate = CGRect(
                x: (width - qrSide) / 2,
                y: topPadding,
                width: qrSide,
                height: qrSide
            )
            let platePath = UIBezierPath(roundedRect: qrPlate.insetBy(dx: -28, dy: -28), cornerRadius: 36)
            UIColor.white.setFill()
            platePath.fill()

            let qrRect = CGRect(
                x: (width - qrSide) / 2,
                y: topPadding,
                width: qrSide,
                height: qrSide
            )
            qrImage.draw(in: qrRect)

            var y = topPadding + qrSide + spacingAfterQR
            let textRect = CGRect(x: horizontalPadding, y: y, width: contentWidth, height: eyebrowHeight)
            draw(
                eyebrow,
                font: eyebrowFont,
                color: UIColor(red: 0.24, green: 0.86, blue: 0.52, alpha: 1),
                in: textRect
            )
            y += eyebrowHeight + 12

            draw(
                routeName,
                font: titleFont,
                color: .white,
                in: CGRect(x: horizontalPadding, y: y, width: contentWidth, height: titleHeight)
            )
            y += titleHeight + 10

            draw(
                statsText,
                font: statsFont,
                color: UIColor(red: 0.70, green: 0.74, blue: 0.78, alpha: 1),
                in: CGRect(x: horizontalPadding, y: y, width: contentWidth, height: statsHeight)
            )
            y += statsHeight + 28

            draw(
                instruction,
                font: instructionFont,
                color: UIColor(red: 0.78, green: 0.81, blue: 0.84, alpha: 1),
                in: CGRect(x: horizontalPadding, y: y, width: contentWidth, height: instructionHeight)
            )
        }
    }

    private static func height(of text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
    }

    private static func draw(_ text: String, font: UIFont, color: UIColor, in rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}
