//
//  ShowRouteQRView.swift
//  TraceWay
//

import SwiftUI

struct ShowRouteQRView: View {
    let route: Route
    @State private var viewModel: ShowRouteQRViewModel?
    @State private var isSharePresented = false

    var body: some View {
        Group {
            if let viewModel {
                ShowRouteQRContent(
                    viewModel: viewModel,
                    isSharePresented: $isSharePresented
                )
            } else {
                ProgressView()
                    .tint(TraceWayTheme.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                let model = ShowRouteQRViewModel(route: route)
                viewModel = model
                model.generate()
            }
        }
    }
}

private struct ShowRouteQRContent: View {
    @Bindable var viewModel: ShowRouteQRViewModel
    @Binding var isSharePresented: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(viewModel.route.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(TraceWayTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(
                        "\(TraceWayFormatters.distance(viewModel.route.distanceMeters)) · \(TraceWayFormatters.duration(viewModel.route.durationSeconds))"
                    )
                    .font(.subheadline)
                    .foregroundStyle(TraceWayTheme.accent)
                }
                .padding(.top, 8)

                if viewModel.isGenerating {
                    ProgressView()
                        .tint(TraceWayTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else if let image = viewModel.qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 320)
                        .padding(20)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityLabel("QR code for route \(viewModel.route.name)")

                    Button {
                        isSharePresented = true
                    } label: {
                        Label("Share QR Code", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(TraceWayPrimaryButtonStyle())
                    .accessibilityLabel("Share QR Code")
                    .padding(.horizontal)

                    if let note = viewModel.simplificationNote {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(TraceWayTheme.warning)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Text("Open TraceWay on another phone and scan this code from Routes → Received.")
                        .font(.footnote)
                        .foregroundStyle(TraceWayTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if let title = viewModel.errorTitle, let message = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(TraceWayTheme.warning)
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(TraceWayTheme.textPrimary)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(TraceWayTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .traceWayCard()
                    .padding(.horizontal)
                }
            }
            .padding()
        }
        .traceWayScreenBackground()
        .navigationTitle("Show QR Code")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TraceWayTheme.surface.opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $isSharePresented) {
            if let image = viewModel.shareImage ?? viewModel.qrImage {
                ImageShareSheet(image: image)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

#Preview {
    NavigationStack {
        Text("Preview requires a Route instance")
    }
    .preferredColorScheme(.dark)
}
