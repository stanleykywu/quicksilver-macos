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

@main
struct QuicksilverApp: App {
    @StateObject private var viewModel = AnalyzerViewModel(
        captureService: SystemAudioCaptureService()
    )

    private let updaterController: SPUStandardUpdaterController

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        self.updaterController = controller
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                controller.checkForUpdates(nil)
            }
    }

    var body: some Scene {
        WindowGroup("Quicksilver") {
            MainWindowRoot(
                viewModel: viewModel,
                checkForUpdates: {
                    updaterController.updater.checkForUpdates()
                }
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
                }
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

    var body: some View {
        AnalyzerView(
            viewModel: viewModel,
            checkForUpdates: checkForUpdates
        )
        .frame(width: 320, height: 420)
    }
}

private struct MenuBarRoot: View {
    @ObservedObject var viewModel: AnalyzerViewModel
    let checkForUpdates: () -> Void

    var body: some View {
        AnalyzerView(
            viewModel: viewModel,
            checkForUpdates: checkForUpdates
        )
        .frame(width: 320, height: 420)
    }
}
