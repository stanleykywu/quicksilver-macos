//
//  QuicksilverApp.swift
//  Quicksilver
//
//  Created by Naryna Azizpour on 3/31/26.
//

import SwiftUI
import Sparkle
import Combine

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

private var appDisplayTitle: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    return "Quicksilver \(version)"
}

@main
struct QuicksilverApp: App {
    @StateObject private var viewModel = AnalyzerViewModel(
        captureService: SystemAudioCaptureService()
    )
    @StateObject private var updatesViewModel: CheckForUpdatesViewModel

    private let updaterController: SPUStandardUpdaterController

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        self.updaterController = controller
        _updatesViewModel = StateObject(
                wrappedValue: CheckForUpdatesViewModel(updater: controller.updater)
            )
    }

    var body: some Scene {
        WindowGroup(appDisplayTitle) {
            MainWindowRoot(
                viewModel: viewModel,
                checkForUpdates: {
                    updaterController.updater.checkForUpdates()
                },
                canCheckForUpdates: updatesViewModel.canCheckForUpdates
            )
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }

        MenuBarExtra {
            MenuBarRoot(
                viewModel: viewModel,
                checkForUpdates: {
                    updaterController.updater.checkForUpdates()
                },
                canCheckForUpdates: updatesViewModel.canCheckForUpdates
            )
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}

// need to create these two manual views because otherwise Swift gets confused when
// we re-use the same state both in the app and the menubar version
private struct MainWindowRoot: View {
    @ObservedObject var viewModel: AnalyzerViewModel
    let checkForUpdates: () -> Void
    let canCheckForUpdates: Bool

    var body: some View {
        AnalyzerView(
            viewModel: viewModel,
            checkForUpdates: checkForUpdates,
            canCheckForUpdates: canCheckForUpdates
        )
        .frame(width: 320, height: 450)
    }
}

private struct MenuBarRoot: View {
    @ObservedObject var viewModel: AnalyzerViewModel
    let checkForUpdates: () -> Void
    let canCheckForUpdates: Bool

    var body: some View {
        AnalyzerView(
            viewModel: viewModel,
            checkForUpdates: checkForUpdates,
            canCheckForUpdates: canCheckForUpdates
        )
        .frame(width: 320, height: 450)
    }
}
