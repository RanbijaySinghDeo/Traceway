//
//  RouteShareLinksTests.swift
//  TraceWayTests
//

import CoreLocation
import XCTest
@testable import TraceWay

final class RouteShareLinksTests: XCTestCase {
    private let start = CLLocationCoordinate2D(latitude: 28.613900, longitude: 77.209000)
    private let mid = CLLocationCoordinate2D(latitude: 28.620000, longitude: 77.210000)
    private let end = CLLocationCoordinate2D(latitude: 28.704100, longitude: 77.102500)

    func testLocationPinURLUsesOfficialSearchFormat() {
        let url = RouteShareLinks.locationPinURL(coordinate: end)
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "www.google.com")
        XCTAssertTrue(url.path.contains("/maps/search"))
        XCTAssertTrue(url.absoluteString.contains("api=1"))
        XCTAssertTrue(url.absoluteString.contains("query=28.704100"))
        XCTAssertTrue(url.absoluteString.contains("77.102500"))
    }

    func testDirectionsURLContainsOriginAndDestination() throws {
        let url = try XCTUnwrap(
            RouteShareLinks.googleMapsDirectionsURL(coordinates: [start, mid, end])
        )
        XCTAssertTrue(url.absoluteString.contains("/maps/dir/"))
        XCTAssertTrue(url.absoluteString.contains("origin=28.613900"))
        XCTAssertTrue(url.absoluteString.contains("destination=28.704100"))
        XCTAssertTrue(url.absoluteString.contains("waypoints="))
    }

    func testWhatsAppURLEncodesMapsQueryCharacters() throws {
        let message = RouteShareLinks.whatsAppMessage(
            routeName: "Home → Office",
            coordinates: [start, end],
            distanceMeters: 12_000,
            durationSeconds: 1800
        )

        let whatsappURL = try XCTUnwrap(
            RouteShareLinks.makeWhatsAppURL(scheme: "whatsapp", message: message)
        )
        let waMeURL = try XCTUnwrap(
            RouteShareLinks.makeWhatsAppURL(scheme: "https", message: message)
        )

        XCTAssertEqual(whatsappURL.scheme, "whatsapp")
        XCTAssertEqual(whatsappURL.host, "send")

        let whatsappComponents = try XCTUnwrap(URLComponents(url: whatsappURL, resolvingAgainstBaseURL: false))
        let text = try XCTUnwrap(whatsappComponents.queryItems?.first(where: { $0.name == "text" })?.value)
        XCTAssertTrue(text.contains("https://www.google.com/maps/search/?api=1&query="))
        XCTAssertTrue(text.contains("28.704100,77.102500"))

        // Absolute string should percent-encode reserved chars from the embedded Maps URL.
        XCTAssertTrue(whatsappURL.absoluteString.contains("text="))
        XCTAssertFalse(whatsappURL.absoluteString.contains("?api=1&query="))

        let waMeComponents = try XCTUnwrap(URLComponents(url: waMeURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(waMeURL.host, "wa.me")
        XCTAssertEqual(waMeComponents.queryItems?.first?.name, "text")
    }
}
