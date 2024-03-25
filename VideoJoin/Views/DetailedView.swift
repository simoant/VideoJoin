//
//  DetailedView.swift
//  VideoJoin
//
//  Created by Anton Simonov on 24/3/24.
//

import SwiftUI
import AVFoundation
import AVKit

struct DetailedView: View {
    @StateObject var model: VideoJoinModel
    @StateObject private var playerObserver: PlayerObserver
    @StateObject private var orientationManager = OrientationManager()
    
    private var index: Int
    private var video: Video?

    
    init(model: VideoJoinModel, index: Int) {
        self.video = model.videos[index].video
        
        if let url = video?.url {
            let player = AVPlayer(url: url)
            self._playerObserver = StateObject(wrappedValue: PlayerObserver(player: player))
        } else {
            log("Player Observed NOT initialized")
            self._playerObserver = StateObject(wrappedValue: PlayerObserver(player: nil))
        }
        
        self._model = StateObject(wrappedValue: model)
        self.index = index
    }

    var body: some View {
        ZStack {
            if let player = self.playerObserver.player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(orientationManager.isLandscape ? .all : .init())
                    .onAppear {
                        playerObserver.addPeriodicTimeObserver()
                    }
                    .onDisappear {
                        playerObserver.removePeriodicTimeObserver()
                    }
            }
            VStack {
                Spacer()

                HStack {
                    if model.videos[index].video != nil, let video = video {
                        Button(action: {
                            model.videos[index].video?.trimStart = playerObserver.currentTime
                            if video.trimStart > video.trimEnd {
                                model.videos[index].video?.trimEnd = Double(video.duration)
                            }
                        }) {
                            Text("->|")
                                .font(.footnote)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Text("\(String(format: "%1.f", video.trimStart))s")
                            .foregroundColor(.white)
                        Spacer()
                        
                        Text("\(String(format: "%2.f", playerObserver.currentTime))s")
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(String(format: "%2.f", video.trimEnd))s")
                            .foregroundColor(.white)
                        
                        Button(action: {
                            playerObserver.player?.pause()
                            seekTo(target: playerObserver.currentTime)
                            model.videos[index].video?.trimEnd = playerObserver.currentTime
                            if video.trimStart > video.trimEnd {
                                model.videos[index].video?.trimStart = 0
                            }
                            

                        }) {
                            Text("|<-")
                                .font(.footnote)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    } else {
                        Text("Video not loaded yet...")
                    }
                }
                .padding()
            }
        }
    }
    
    func seekTo(target: Double) {
        let newStartTime = CMTime(seconds: target, preferredTimescale: 600)
        playerObserver.player?.seek(to: newStartTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

}

//#Preview {
//    DetailedView(model: VideoJoinModel(), video: Video())
//}
