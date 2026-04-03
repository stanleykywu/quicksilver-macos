//
//  QuicksilverApp.swift
//  Quicksilver
//
//  Created by Naryna Azizpour on 3/31/26.
//

import SwiftUI

@main
struct QuicksilverApp: App {
    @StateObject private var viewModel = AnalyzerViewModel(
        captureService: SystemAudioCaptureService()
    )

    var body: some Scene {
        WindowGroup("Quicksilver") {
            MainWindowRoot(viewModel: viewModel)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarRoot(viewModel: viewModel)
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

    var body: some View {
        AnalyzerView(viewModel: viewModel)
            .frame(width: 320, height: 420)
    }
}

private struct MenuBarRoot: View {
    @ObservedObject var viewModel: AnalyzerViewModel

    var body: some View {
        AnalyzerView(viewModel: viewModel)
            .frame(width: 320, height: 420)
    }
}
