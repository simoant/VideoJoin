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
        if let composition = model.mergedVideo?.composition {
            VideoPlayer(player: AVPlayer(playerItem: AVPlayerItem(asset: composition)))
        }
    }
}

#Preview {
    PreviewVideoPlayer(model: VideoJoinModel())
}
