//
//  TimerModel.swift
//  VideoJoin
//
//  Created by Anton Simonov on 26/3/24.
//

import Foundation
import SwiftUI
import Combine

class ProgressModel: ObservableObject {
    @Published var progress: Double = 0.0
    private var progressSupplier: () -> Double
    private var timer: AnyCancellable?
    
    init(progress: Double, progressSupplier: @escaping () -> Double) {
        self.progress = progress
        self.progressSupplier = progressSupplier
        self.timer = nil
    }

    @MainActor func startTrackingProgress() {
        // Reset progress
        progress = 0.0
        
        // Schedule a timer
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                let newProgress = self.progressSupplier()

                if newProgress < 1.0 { // Or your specific end condition
                    self.progress = newProgress
                } else {
                    self.progress = 1.0
                    self.timer?.cancel() // Stop the timer when the condition is met
                }
            }
    }

    deinit {
        timer?.cancel()
    }
}

