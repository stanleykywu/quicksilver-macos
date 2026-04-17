//
//  AnalyzerView.swift
//  Quicksilver
//
//  Created by Naryna Azizpour on 3/31/26.
//

import SwiftUI
import AppKit

func appIcon(for source: AudioSource) -> NSImage? {
    guard let bundleID = source.bundleIdentifier,
          let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    else {
        return nil
    }

    return NSWorkspace.shared.icon(forFile: appURL.path)
}

struct ContextCursorOnHover: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active(_):
                    if isEnabled {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.operationNotAllowed.set()
                    }

                case .ended:
                    NSCursor.arrow.set()
                }
            }
    }
}

extension View {
    func contextCursorOnHover(enabled: Bool) -> some View {
        modifier(ContextCursorOnHover(isEnabled: enabled))
    }
}

private struct SmoothProgressBar: View {
    let progress: Double
    let fillColor: Color

    var body: some View {
        GeometryReader { geometry in
            let clampedProgress = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(fillColor.opacity(0.18))

                RoundedRectangle(cornerRadius: 4)
                    .fill(fillColor)
                    .frame(width: geometry.size.width * clampedProgress)
            }
        }
        .frame(height: 8)
    }
}

private struct HoverUnderlineLink: View {
    let title: String
    let destination: URL
    let color: Color

    @State private var isHovering = false

    var body: some View {
        Link(destination: destination) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
                .underline(isHovering)
                .multilineTextAlignment(.trailing)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
        .contextCursorOnHover(enabled: true)
        .onContinuousHover { phase in
            switch phase {
            case .active(_):
                isHovering = true
            case .ended:
                isHovering = false
            }
        }
    }
}

struct AnalyzerView: View {
    @ObservedObject var viewModel: AnalyzerViewModel
    let checkForUpdates: () -> Void
    let canCheckForUpdates: Bool

    private let pageBackgroundTop = Color(red: 247/255, green: 244/255, blue: 234/255)
    private let pageBackgroundBottom = Color.white
    private let primaryButtonColor = Color(red: 18/255, green: 103/255, blue: 130/255)
    private let secondaryButtonColor = Color(red: 217/255, green: 226/255, blue: 236/255)
    private let secondaryButtonTextColor = Color(red: 36/255, green: 59/255, blue: 83/255)
    private let bodyTextColor = Color(red: 31/255, green: 41/255, blue: 51/255)
    private let mutedTextColor = Color(red: 82/255, green: 96/255, blue: 109/255)
    private let emptyBackgroundColor = Color(red: 240/255, green: 244/255, blue: 248/255)
    private let warningBackground = Color(red: 254/255, green: 243/255, blue: 199/255)
    private let warningText = Color(red: 146/255, green: 64/255, blue: 14/255)

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 16) {

                Text("Please play music as you would normally. While the music is playing, select the corresponding app from the dropdown (e.g., Spotify), and press \"Analyze\". Allow music to play for 30 seconds to avoid incomplete results.")
                    .font(.system(size: 14))
                    .foregroundStyle(bodyTextColor.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Audio Source")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(mutedTextColor)
                            .textCase(.uppercase)

                        Spacer()
                    }

                    Menu {
                        Button("Select an app") {
                            viewModel.selectedSource = nil
                        }

                        Divider()

                        ForEach(viewModel.availableSources, id: \.self) { source in
                            Button {
                                viewModel.selectedSource = source
                            } label: {
                                HStack(spacing: 8) {
                                    if let icon = appIcon(for: source) {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }

                                    Text(source.appName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if let icon = viewModel.selectedSource.flatMap({ appIcon(for: $0) }) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }

                            Text(viewModel.selectedSource?.appName ?? "Select an app")
                                .foregroundStyle(
                                    viewModel.selectedSource == nil
                                    ? mutedTextColor
                                    : bodyTextColor
                                )

                            Spacer()

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(mutedTextColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(emptyBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .contextCursorOnHover(enabled: !viewModel.isRecording)
                    .allowsHitTesting(!viewModel.isRecording)
                    .overlay {
                        if viewModel.isRecording {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.clear)
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                                .contextCursorOnHover(enabled: false)
                        }
                    }
                }

                if let warning = viewModel.sourceWarning {
                    Text(warning)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(warningText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(warningBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if viewModel.isRecording {
                    VStack(spacing: 10) {
                        SmoothProgressBar(progress: viewModel.progress, fillColor: primaryButtonColor)

                        Text(viewModel.timerText())
                            .font(.system(size: 32, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(bodyTextColor)
                    }
                }

                HStack(spacing: 10) {
                    Button("Analyze") {
                        viewModel.startAnalysis()
                    }
                    .buttonStyle(FilledButtonStyle(
                        background: primaryButtonColor,
                        foreground: .white
                    ))
                    .disabled(viewModel.isRecording)
                    .contextCursorOnHover(enabled: !viewModel.isRecording)

                    Button("Cancel") {
                        viewModel.cancelAnalysis()
                    }
                    .buttonStyle(FilledButtonStyle(
                        background: secondaryButtonColor,
                        foreground: secondaryButtonTextColor
                    ))
                    .disabled(!viewModel.isRecording)
                    .opacity(viewModel.isRecording ? 1 : 0.65)
                    .contextCursorOnHover(enabled: viewModel.isRecording)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Results")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(mutedTextColor)
                        .textCase(.uppercase)

                    if viewModel.results.isEmpty {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(emptyBackgroundColor)
                            .frame(height: 52)
                            .overlay(alignment: .leading) {
                                Text("No results yet")
                                    .font(.system(size: 13))
                                    .foregroundStyle(mutedTextColor)
                                    .padding(.horizontal, 12)
                            }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(viewModel.results) { result in
                                ResultCard(result: result)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)

            HStack(spacing: 12) {
                Button {
                    viewModel.quitApp()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                            .font(.system(size: 13, weight: .semibold))

                        Text("Quit")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(mutedTextColor)
                }
                .buttonStyle(.plain)
                .contextCursorOnHover(enabled: true)
                
                Button {
                    checkForUpdates()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))

                        Text("Check for Updates")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(mutedTextColor)
                }
                .buttonStyle(.plain)
                .disabled(!canCheckForUpdates)
                .contextCursorOnHover(enabled: canCheckForUpdates)
                .opacity(canCheckForUpdates ? 1 : 0.65)

                Spacer()

                HoverUnderlineLink(
                    title: "Brought to you by ETCH Lab",
                    destination: URL(string: "http://etch-humanity.org/etch-lab")!,
                    color: mutedTextColor
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [pageBackgroundTop, pageBackgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            viewModel.loadSources()
        }
    }
}

private struct ResultCard: View {
    let result: DetectionResult

    private var backgroundColor: Color {
        result.isLikely
        ? Color(red: 253/255, green: 232/255, blue: 232/255)
        : Color(red: 230/255, green: 244/255, blue: 234/255)
    }

    private let bodyTextColor = Color(red: 31/255, green: 41/255, blue: 51/255)
    private let mutedTextColor = Color(red: 82/255, green: 96/255, blue: 109/255)
    private let warningBackground = Color(red: 254/255, green: 243/255, blue: 199/255)
    private let warningText = Color(red: 146/255, green: 64/255, blue: 14/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.verdict)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(bodyTextColor)

            Text(result.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(bodyTextColor)

            if let probability = result.probabilityText {
                Text(probability)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(mutedTextColor)
            }

            if let warning = result.warning {
                Text(warning)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(warningText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(warningBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct FilledButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                background
                    .opacity(configuration.isPressed ? 0.9 : 1.0)
            )
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}
