//
//  MergedVideoView.swift
//  VideoJoin
//
//  Created by Anton Simonov on 24/3/24.
//

import SwiftUI
import AVFoundation
import AVKit

struct MergedVideoView: View {
    @StateObject var model: VideoJoinModel
    var body: some View {
        if let url = model.mergedVideo?.url {
            VideoPlayer(player: AVPlayer(url: url))
        }
    }
}

#Preview {
    MergedVideoView(model: VideoJoinModel())
}
