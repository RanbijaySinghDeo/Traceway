//
//  RecordRouteViewModel.swift
//  TraceWay
//

import CoreLocation
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class RecordRouteViewModel {
    private let locationService: any LocationServing
    private let routeStore: any RouteStoring
    private let routeExporter: any RouteExporting
    private let recorder: RouteRecorder
    private let qualityThresholds: GPSQualityThresholds

    private var locationTask: Task<Void, Never>?
    private var authorizationTask: Task<Void, Never>?
    private var durationTickTask: Task<Void, Never>?

    var authorizationState: LocationAuthorizationState = .notDetermined
    var recordingState: RecordingState = .idle
    var latestLocation: LocationPoint?
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var distanceMeters: Double = 0
    var durationSeconds: TimeInterval = 0
    var gpsQuality: GPSQuality = .unknown
    var errorMessage: String?
    var pendingSaveSnapshot: RecordingSnapshot?
    var routeNameDraft = ""
    var isSaving = false
    var shareFileURL: URL?
    var isSharePresented = false
    var isShareOptionsPresented = false
    private var didPersistCompletion = false
    private var didStartObservers = false

    var showsCompletionModal: Bool {
        pendingSaveSnapshot != nil
    }

    var canStart: Bool {
        recordingState == .idle && authorizationState.canRecordRoute && !showsCompletionModal
    }

    var isSessionActive: Bool {
        recordingState == .recording || recordingState == .paused
    }

    init(
        locationService: any LocationServing,
        routeStore: any RouteStoring,
        routeExporter: any RouteExporting = RouteExporter(),
        qualityThresholds: GPSQualityThresholds = .default,
        recorder: RouteRecorder? = nil
    ) {
        self.locationService = locationService
        self.routeStore = routeStore
        self.routeExporter = routeExporter
        self.qualityThresholds = qualityThresholds
        self.recorder = recorder ?? RouteRecorder()
    }

    func onAppear() {
        authorizationState = locationService.authorizationState
        latestLocation = locationService.latestLocation

        if !didStartObservers {
            observeAuthorization()
            observeLocations()
            didStartObservers = true
        }

        if authorizationState.canShowUserLocation || authorizationState == .notDetermined {
            startPreviewIfNeeded()
        }
    }

    func onDisappear() {
        // Keep recording/location running across tab switches while a session is active.
        guard !isSessionActive else { return }
        stopPreview()
    }

    func requestAccess() {
        switch authorizationState {
        case .notDetermined:
            locationService.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            locationService.requestAlwaysAuthorization()
        case .preciseLocationDisabled:
            Task {
                await locationService.requestTemporaryFullAccuracyAuthorization()
            }
        default:
            break
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func startRecording() {
        errorMessage = nil
        guard authorizationState.canRecordRoute else {
            errorMessage = authorizationState.settingsGuidanceMessage
            requestAccess()
            return
        }

        do {
            try recorder.start()
            recordingState = recorder.state
            publishRecorderMetrics()
            locationService.startUpdating(with: .recording)
            if authorizationState == .authorizedWhenInUse {
                locationService.requestAlwaysAuthorization()
            }
            startDurationTicks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pauseRecording() {
        do {
            try recorder.pause()
            recordingState = recorder.state
            publishRecorderMetrics()
            durationTickTask?.cancel()
            durationTickTask = nil
            // No points accepted while paused — stop GPS to save battery.
            locationService.stopUpdating()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resumeRecording() {
        do {
            try recorder.resume()
            recordingState = recorder.state
            publishRecorderMetrics()
            locationService.startUpdating(with: .recording)
            startDurationTicks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() {
        do {
            let snapshot = try recorder.stop()
            recordingState = recorder.state
            durationTickTask?.cancel()
            durationTickTask = nil
            locationService.stopUpdating()

            guard !snapshot.points.isEmpty else {
                errorMessage = "No GPS points were recorded. Try again when GPS accuracy improves."
                resetLiveTrack()
                startPreviewIfNeeded()
                return
            }

            pendingSaveSnapshot = snapshot
            routeNameDraft = defaultRouteName(for: snapshot)
            didPersistCompletion = false
            distanceMeters = snapshot.distanceMeters
            durationSeconds = snapshot.durationSeconds
            routeCoordinates = snapshot.points.map(\.coordinate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelSave() {
        pendingSaveSnapshot = nil
        shareFileURL = nil
        isSharePresented = false
        isShareOptionsPresented = false
        didPersistCompletion = false
        resetLiveTrack()
        startPreviewIfNeeded()
    }

    /// Close button on the completion modal — saves then returns to idle Record UI.
    func closeCompletionModal() {
        _ = persistCompletionIfNeeded()
        pendingSaveSnapshot = nil
        shareFileURL = nil
        isSharePresented = false
        isShareOptionsPresented = false
        resetLiveTrack()
        startPreviewIfNeeded()
    }

    func presentShareOptions() {
        isShareOptionsPresented = true
    }

    func prepareAndPresentGPXShare() {
        guard let snapshot = pendingSaveSnapshot else { return }
        _ = persistCompletionIfNeeded()

        let name = routeNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? defaultRouteName(for: snapshot)

        do {
            shareFileURL = try routeExporter.writeTemporaryGPXFile(
                name: name,
                points: snapshot.points,
                createdAt: snapshot.startedAt ?? .now
            )
            isSharePresented = shareFileURL != nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Shares a tappable Maps location/route link in WhatsApp (not GPX files).
    func shareCompletionViaWhatsApp() {
        guard let snapshot = pendingSaveSnapshot else { return }
        _ = persistCompletionIfNeeded()

        let name = routeNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? defaultRouteName(for: snapshot)
        let coordinates = snapshot.points.map(\.coordinate)

        let opened = RouteShareLinks.shareViaWhatsApp(
            routeName: name,
            coordinates: coordinates,
            distanceMeters: snapshot.distanceMeters,
            durationSeconds: snapshot.durationSeconds
        )
        if !opened {
            errorMessage = "WhatsApp is not available on this device."
        }
    }

    func openCompletionInAppleMaps() {
        guard let snapshot = pendingSaveSnapshot,
              let start = snapshot.points.first,
              let end = snapshot.points.last
        else { return }
        ExternalMapsOpener.openInAppleMaps(start: start.coordinate, end: end.coordinate)
    }

    func openCompletionInGoogleMaps() {
        guard let snapshot = pendingSaveSnapshot,
              let start = snapshot.points.first,
              let end = snapshot.points.last
        else { return }
        ExternalMapsOpener.openInGoogleMaps(start: start.coordinate, end: end.coordinate)
    }

    @discardableResult
    private func persistCompletionIfNeeded() -> Bool {
        guard !didPersistCompletion else { return true }
        guard let snapshot = pendingSaveSnapshot else { return false }
        guard let startedAt = snapshot.startedAt, let endedAt = snapshot.endedAt else {
            errorMessage = "Recording timestamps were missing."
            return false
        }

        isSaving = true
        let trimmed = routeNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? defaultRouteName(for: snapshot) : trimmed
        routeNameDraft = name

        let draft = RouteDraft(
            name: name,
            startedAt: startedAt,
            endedAt: endedAt,
            distanceMeters: snapshot.distanceMeters,
            durationSeconds: snapshot.durationSeconds,
            quality: snapshot.quality,
            points: snapshot.points
        )

        do {
            _ = try routeStore.save(draft)
            didPersistCompletion = true
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    private func observeAuthorization() {
        authorizationTask?.cancel()
        authorizationTask = Task {
            for await state in locationService.authorizationUpdates {
                authorizationState = state
                if state.canShowUserLocation, !isSessionActive {
                    startPreviewIfNeeded()
                }
                if !state.canRecordRoute, isSessionActive {
                    // Keep session; surface guidance without auto-stopping.
                    errorMessage = state.settingsGuidanceMessage
                }
            }
        }
    }

    private func observeLocations() {
        locationTask?.cancel()
        locationTask = Task {
            for await point in locationService.locationUpdates {
                latestLocation = point
                gpsQuality = GPSQuality(
                    horizontalAccuracyMeters: point.horizontalAccuracy,
                    thresholds: qualityThresholds
                )

                if recordingState == .recording {
                    let evaluation = recorder.ingest(point)
                    if case .accept = evaluation {
                        publishRecorderMetrics()
                    }
                }
            }
        }
    }

    private func startPreviewIfNeeded() {
        guard !isSessionActive else { return }
        guard authorizationState.canShowUserLocation else { return }
        if !locationService.isUpdating {
            locationService.startUpdating(with: .preview)
        }
    }

    private func stopPreview() {
        guard !isSessionActive else { return }
        locationService.stopUpdating()
    }

    private func startDurationTicks() {
        durationTickTask?.cancel()
        durationTickTask = Task {
            while !Task.isCancelled, recordingState == .recording {
                durationSeconds = recorder.durationSeconds
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func publishRecorderMetrics() {
        recordingState = recorder.state
        distanceMeters = recorder.distanceMeters
        durationSeconds = recorder.durationSeconds
        routeCoordinates = recorder.points.map(\.coordinate)
    }

    private func resetLiveTrack() {
        routeCoordinates = []
        distanceMeters = 0
        durationSeconds = 0
        recordingState = .idle
    }

    private func defaultRouteName(for snapshot: RecordingSnapshot) -> String {
        let date = snapshot.startedAt ?? .now
        return "Route \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}