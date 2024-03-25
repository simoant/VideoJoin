import Foundation
import AVFoundation

class PlayerObserver: ObservableObject {
    var timeObserverToken: Any?
    weak var player: AVPlayer?
    @Published var currentTime: TimeInterval = 0

    init(player: AVPlayer?) {
        self.player = player
    }

    func addPeriodicTimeObserver() {
        guard let player = player else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }

    func removePeriodicTimeObserver() {
        if let token = timeObserverToken, let player = player {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    deinit {
        removePeriodicTimeObserver()
    }
}
