//
//  CaptureService.swift
//  Quicksilver
//
//  Created by Naryna Azizpour on 3/31/26.
//

import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import AVFoundation

struct AudioSource: Identifiable, Equatable, Hashable {
    let id: String
    let appName: String
    let bundleIdentifier: String?
    let application: SCRunningApplication

    static func == (lhs: AudioSource, rhs: AudioSource) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
final class SystemAudioCaptureService: NSObject, CaptureService {
    private var stream: SCStream?
    private let audioOutput = SystemAudioStreamOutput()
    private let screenOutput = NullScreenOutput()

    private var startedAt: Date?
    private var duration: TimeInterval = 30
    private var selectedSource: AudioSource?

    private var onTick: ((_ remaining: TimeInterval, _ progress: Double) -> Void)?
    private var onComplete: ((Result<[DetectionResult], Error>) -> Void)?

    private var progressTask: Task<Void, Never>?
    private var totalSampleFrames: Int = 0
    private var capturedBufferCount: Int = 0
    private var latestSampleRate: Double = 48_000

    private var capturedSamples: [Float] = []

    func availableAudioSources() async throws -> [AudioSource] {
        let hasAccess = CGPreflightScreenCaptureAccess()
        if !hasAccess {
            let granted = CGRequestScreenCaptureAccess()
            guard granted else {
                throw CaptureError.permissionDenied
            }
        }

        let shareableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        let apps = shareableContent.applications
            .filter { app in
                let name = app.applicationName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    return false
                }

                if app.bundleIdentifier == Bundle.main.bundleIdentifier {
                    return false // don't let them pick our app
                }

                return true
            }
            .map { app in
                AudioSource(
                    id: app.bundleIdentifier,
                    appName: app.applicationName,
                    bundleIdentifier: app.bundleIdentifier,
                    application: app
                )
            }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }

        return apps
    }

    func startCapture(
        from source: AudioSource,
        duration: TimeInterval,
        onTick: @escaping (_ remaining: TimeInterval, _ progress: Double) -> Void,
        onComplete: @escaping (Result<[DetectionResult], Error>) -> Void
    ) {
        cancelCapture()

        self.duration = duration
        self.selectedSource = source
        self.onTick = onTick
        self.onComplete = onComplete
        self.totalSampleFrames = 0
        self.capturedBufferCount = 0
        self.latestSampleRate = 48_000
        self.capturedSamples = []

        Task { @MainActor in
            do {
                try await self.startSystemAudioCapture(for: source)
            } catch {
                self.finish(with: .failure(error))
            }
        }
    }

    func cancelCapture() {
        progressTask?.cancel()
        progressTask = nil

        let currentStream = stream

        Task {
            try? await currentStream?.stopCapture()
            await MainActor.run {
                self.stream = nil
            }
        }

        audioOutput.onPCMBuffer = nil
        onTick = nil
        onComplete = nil
        startedAt = nil
        capturedSamples = []
        selectedSource = nil
    }

    @MainActor
    private func startSystemAudioCapture(for source: AudioSource) async throws {
        let hasAccess = CGPreflightScreenCaptureAccess()
        if !hasAccess {
            let granted = CGRequestScreenCaptureAccess()
            guard granted else {
                throw CaptureError.permissionDenied
            }
        }

        let shareableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = shareableContent.displays.first else {
            throw CaptureError.noDisplayAvailable
        }

        // Re-resolve the application from the latest shareable content
        guard let matchingApp = shareableContent.applications.first(where: {
            if let bundleID = source.bundleIdentifier, $0.bundleIdentifier == bundleID {
                return true
            }
            return $0.applicationName == source.appName
        }) else {
            throw CaptureError.sourceUnavailable
        }

        let filter = SCContentFilter(
            display: display,
            including: [matchingApp],
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2

        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)

        audioOutput.onPCMBuffer = { [weak self] pcmBuffer in
            guard let self else { return }

            Task { @MainActor in
                self.capturedBufferCount += 1
                self.latestSampleRate = pcmBuffer.format.sampleRate
                self.totalSampleFrames += Int(pcmBuffer.frameLength)

                let monoSamples = Self.extractMonoSamples(from: pcmBuffer)
                if !monoSamples.isEmpty {
                    self.capturedSamples.append(contentsOf: monoSamples)
                }
            }
        }

        try stream.addStreamOutput(
            audioOutput,
            type: .audio,
            sampleHandlerQueue: DispatchQueue(label: "quicksilver.audio-output")
        )

        try stream.addStreamOutput(
            screenOutput,
            type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "quicksilver.screen-output")
        )

        self.stream = stream
        self.startedAt = Date()

        onTick?(duration, 0)

        progressTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let maybeStartedAt = await MainActor.run { self.startedAt }
                let currentDuration = await MainActor.run { self.duration }

                guard let startedAt = maybeStartedAt else { return }

                let elapsed = Date().timeIntervalSince(startedAt)
                let remaining = max(0, currentDuration - elapsed)
                let progress = min(1, elapsed / currentDuration)

                await MainActor.run {
                    self.onTick?(remaining, progress)
                }

                if elapsed >= currentDuration {
                    do {
                        let currentStream = await MainActor.run { self.stream }
                        try await currentStream?.stopCapture()

                        await MainActor.run {
                            self.stream = nil
                            self.progressTask = nil
                            self.completeWithInference()
                        }
                    } catch {
                        await MainActor.run {
                            self.progressTask = nil
                            self.finish(with: .failure(error))
                        }
                    }
                    return
                }

                try? await Task.sleep(for: .milliseconds(16))
            }
        }

        try await stream.startCapture()
    }

    private func completeWithInference() {
        let sourceName = selectedSource?.appName ?? "Selected App"
        let hasSamples = !capturedSamples.isEmpty && capturedBufferCount > 0

        guard hasSamples else {
            let result = DetectionResult(
                verdict: "No Audio Detected",
                title: "Audio from: " + (selectedSource?.appName ?? "Selected App"),
                probabilityText: nil,
                warning: "Nothing was recorded. Please play audio and try again.",
                isLikely: false
            )

            finish(with: .success([result]))
            return
        }

        let zeroCount = capturedSamples.reduce(0) { count, sample in
            count + (sample == 0 ? 1 : 0)
        }

        let zeroFraction = Double(zeroCount) / Double(capturedSamples.count)
        let hasSufficientAudio = zeroFraction < 0.5
        
        guard hasSufficientAudio else {
            let result = DetectionResult(
                verdict: "No Audio Detected",
                title: "Audio from: " + (selectedSource?.appName ?? "Selected App"),
                probabilityText: nil,
                warning: "No meaningful audio detected.\nMake sure sound is playing.",
                isLikely: false
            )

            finish(with: .success([result]))
            return
        }

        let score = RustBackend.runInference(
            samples: capturedSamples,
            sampleRate: latestSampleRate
        )

        let percentage = Int((max(0, min(score, 1)) * 100).rounded())

        let isLikely = score >= 0.8

        let result = DetectionResult(
            verdict: isLikely ? "Likely AI" : "Unlikely AI",
            title: "Audio from: " + sourceName,
            probabilityText: isLikely ? "Probability: \(percentage)%" : nil,
            warning: nil,
            isLikely: isLikely
        )

        finish(with: .success([result]))
    }

    private func finish(with result: Result<[DetectionResult], Error>) {
        progressTask?.cancel()
        progressTask = nil

        let completion = onComplete
        onComplete = nil
        onTick = nil
        startedAt = nil
        completion?(result)
    }

    private static func extractMonoSamples(from pcmBuffer: AVAudioPCMBuffer) -> [Float] {
        let frameLength = Int(pcmBuffer.frameLength)
        guard frameLength > 0 else { return [] }

        guard let channelData = pcmBuffer.floatChannelData else { return [] }

        let channelCount = Int(pcmBuffer.format.channelCount)
        guard channelCount > 0 else { return [] }

        if channelCount == 1 {
            let source = channelData[0]
            return Array(UnsafeBufferPointer(start: source, count: frameLength))
        }

        var mono = [Float](repeating: 0, count: frameLength)

        for frame in 0..<frameLength {
            var sum: Float = 0
            for channel in 0..<channelCount {
                sum += channelData[channel][frame]
            }
            mono[frame] = sum / Float(channelCount)
        }

        return mono
    }
}

private final class SystemAudioStreamOutput: NSObject, SCStreamOutput {
    var onPCMBuffer: ((AVAudioPCMBuffer) -> Void)?

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio else { return }
        guard sampleBuffer.isValid else { return }
        guard let formatDescription = sampleBuffer.formatDescription else { return }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else { return }

        guard asbd.pointee.mSampleRate > 0 else { return }
        guard asbd.pointee.mChannelsPerFrame > 0 else { return }

        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0 else { return }

        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: asbd.pointee.mSampleRate,
            channels: asbd.pointee.mChannelsPerFrame,
            interleaved: false
        )

        guard let audioFormat else { return }
        guard let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(numSamples)
        ) else {
            return
        }

        pcmBuffer.frameLength = AVAudioFrameCount(numSamples)

        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(numSamples),
            into: pcmBuffer.mutableAudioBufferList
        )

        guard status == noErr else { return }
        onPCMBuffer?(pcmBuffer)
    }
}

private final class NullScreenOutput: NSObject, SCStreamOutput {
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        // ignoring video frames
    }
}

enum CaptureError: LocalizedError {
    case permissionDenied
    case noDisplayAvailable
    case sourceUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen/audio capture permission was denied.\nEnable Quicksilver in System Settings and try again."
        case .noDisplayAvailable:
            return "No display is available for starting system audio capture."
        case .sourceUnavailable:
            return "The selected app is no longer available. Please select it again."
        }
    }
}
