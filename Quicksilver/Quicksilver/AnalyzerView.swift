//
//  AnalyzerView.swift
//  Quicksilver
//
//  Created by Naryna Azizpour on 3/31/26.
//

import SwiftUI

struct AnalyzerView: View {
    @ObservedObject var viewModel: AnalyzerViewModel

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
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 16) {

                Text("Choose the app you want to analyze, then play audio from that app and press Analyze. Let it play for 30 seconds for the best result.")
                    .font(.system(size: 14))
                    .foregroundStyle(bodyTextColor.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

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
                            Button(source.appName) {
                                viewModel.selectedSource = source
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
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
                    .allowsHitTesting(!viewModel.isRecording)
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
                        ProgressView(value: viewModel.progress)
                            .progressViewStyle(.linear)
                            .tint(primaryButtonColor)

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

                    Button("Cancel") {
                        viewModel.cancelAnalysis()
                    }
                    .buttonStyle(FilledButtonStyle(
                        background: secondaryButtonColor,
                        foreground: secondaryButtonTextColor
                    ))
                    .disabled(!viewModel.isRecording)
                    .opacity(viewModel.isRecording ? 1 : 0.65)
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

            Link("placeholder link", destination: URL(string: "https://example.com")!)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(mutedTextColor)
                .padding(.trailing, 12)
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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(background.opacity(configuration.isPressed ? 0.9 : 1.0))
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
