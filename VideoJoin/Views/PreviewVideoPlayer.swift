//
//  PreviewVideoPlayer.swift
//  VideoJoin
//
//  Created by Anton Simonov on 25/3/24.
//

import SwiftUI
import AVFoundation
import AVKit

struct PreviewVideoPlayer: View {
    @StateObject var model: VideoJoinModel
    var body: some View {
        if let avPlayerItem = getAvPlayerItem() {
            VideoPlayer(player: AVPlayer(playerItem: avPlayerItem))
        }
    }
    
    func getAvPlayerItem() -> AVPlayerItem? {
        if let composition = model.mergedVideo?.composition, let videoCompsition = model.mergedVideo?.videoComposition {
            let avPlayerItem = AVPlayerItem(asset: composition)
            avPlayerItem.videoComposition = videoCompsition
            return avPlayerItem
        }
        return nil
    }
}

#Preview {
    PreviewVideoPlayer(model: VideoJoinModel())
}
