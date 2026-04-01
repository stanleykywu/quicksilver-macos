//
//  RustBackend.swift
//  Quicksilver
//
//  Created by Naryna Azizpour on 4/1/26.
//

import Foundation

enum RustBackend {
    static func runInference(samples: [Float], sampleRate: Double) -> Float {
        guard !samples.isEmpty else { return 0 }

        return samples.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return 0 }

            return qs_run_inference(
                baseAddress,
                UInt(buffer.count),
                UInt32(sampleRate.rounded())
            )
        }
    }
}
