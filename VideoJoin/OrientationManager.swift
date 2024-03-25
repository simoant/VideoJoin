//
//  OrientationManager.swift
//  VideoJoin
//
//  Created by Anton Simonov on 19/2/24.
//

import UIKit
import Combine

class OrientationManager: ObservableObject {
    @Published var isLandscape: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Start observing orientation changes right when the object is initialized
        setupOrientationChangeObserver()
    }
    
    private func setupOrientationChangeObserver() {
        // Use NotificationCenter to observe device orientation changes
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Update isLandscape based on the current device orientation
                let orientation = UIDevice.current.orientation
                switch orientation {
                case .landscapeLeft, .landscapeRight:
                    self.isLandscape = true
                case .portrait, .portraitUpsideDown:
                    self.isLandscape = false
                default:
                    break // Ignore other orientations like .faceUp and .faceDown
                }
            }
            .store(in: &cancellables)
        
        // Ensure the device is capable of monitoring orientation
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }
    
    deinit {
        // Stop observing and generating device orientation notifications
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        
        // Cancel any subscriptions to prevent memory leaks
        cancellables.forEach { $0.cancel() }
    }
}
