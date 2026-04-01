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
        WindowGroup {
            AnalyzerView(viewModel: viewModel)
                .frame(width: 320, height: 420)
        }
        .windowResizability(.contentSize)
    }
}
