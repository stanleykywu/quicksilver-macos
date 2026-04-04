//
//  AnalyzerViewModel.swift
//  Quicksilver
//
//  Created by Naryna Azizpour on 3/31/26.
//

import Foundation
import SwiftUI
import Combine
import AppKit

struct DetectionResult: Identifiable, Equatable {
    let id = UUID()
    let verdict: String
    let title: String
    let probabilityText: String?
    let warning: String?
    let isLikely: Bool
}

enum AnalyzerState: Equatable {
    case idle
    case recording
    case processing
    case completed
    case failed(String)
}

protocol CaptureService {
    func availableAudioSources() async throws -> [AudioSource]

    func startCapture(
        from source: AudioSource,
        duration: TimeInterval,
        onTick: @escaping (_ remaining: TimeInterval, _ progress: Double) -> Void,
        onComplete: @escaping (Result<[DetectionResult], Error>) -> Void
    )

    func cancelCapture()
}

@MainActor
final class AnalyzerViewModel: ObservableObject {
    @Published var state: AnalyzerState = .idle
    @Published var remainingSeconds: Int = 30
    @Published var progress: Double = 0
    @Published var results: [DetectionResult] = []

    @Published var availableSources: [AudioSource] = []
    @Published var selectedSource: AudioSource?
    @Published var sourceWarning: String?

    private let captureService: CaptureService

    init(captureService: CaptureService) {
        self.captureService = captureService
    }

    var isRecording: Bool {
        if case .recording = state { return true }
        if case .processing = state { return true }
        return false
    }

    func loadSources() {
        Task { @MainActor in
            do {
                let sources = try await captureService.availableAudioSources()
                self.availableSources = sources

                if let selectedSource,
                   sources.contains(selectedSource) == false {
                    self.selectedSource = nil
                }

                self.sourceWarning = nil
            } catch {
                self.availableSources = []
                self.selectedSource = nil
                self.sourceWarning = error.localizedDescription
            }
        }
    }

    func startAnalysis() {
        guard !isRecording else { return }

        sourceWarning = nil

        guard let selectedSource else {
            sourceWarning = "Pick one app before starting analysis."
            return
        }

        state = .recording
        remainingSeconds = 30
        progress = 0
        results = []

        captureService.startCapture(
            from: selectedSource,
            duration: 30,
            onTick: { [weak self] remaining, progress in
                Task { @MainActor in
                    self?.remainingSeconds = max(0, Int(ceil(remaining)))
                    self?.progress = min(max(progress, 0), 1)
                }
            },
            onComplete: { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    switch result {
                    case .success(let results):
                        self.state = .completed
                        self.progress = 1
                        self.remainingSeconds = 0
                        self.results = results
                    case .failure(let error):
                        self.state = .failed(error.localizedDescription)
                    }
                }
            }
        )
    }

    func cancelAnalysis() {
        captureService.cancelCapture()
        state = .idle
        remainingSeconds = 30
        progress = 0
    }

    func quitApp() {
        captureService.cancelCapture()
        NSApplication.shared.terminate(nil)
    }
    
    func timerText() -> String {
        let seconds = max(0, remainingSeconds)
        return String(format: "00:%02d", seconds)
    }
}
