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
    
    private var index: Int = 0
    private var video: Video? = nil
    
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
        if let player = self.playerObserver.player {
            if orientationManager.isLandscape {
                ZStack {
                    Spacer()
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)
                    
                        .onAppear {
                            playerObserver.addPeriodicTimeObserver()
                        }
                        .onDisappear {
                            playerObserver.removePeriodicTimeObserver()
                        }
                    VStack {
                        Spacer()
                        buttons(color: .white)
                            .padding()
                    }
                }
            } else {
                GeometryReader { dim in
                    let videoSize = video?.resolution ?? CGSize(width: 0, height: 0)
                    let scale = (dim.size.width - 2 * 15) / videoSize.width
                    let height = (videoSize.height * scale)
                    
                    VStack(alignment: .center) {
                        Spacer()
                        VideoPlayer(player: player)
                            .frame(height: height)
                            .cornerRadius(8)
                            .shadow(radius: 5)
                            
                            .onAppear {
                                do {
                                    try AVAudioSession.sharedInstance().setCategory(.playback)
                                    try AVAudioSession.sharedInstance().setActive(true)
                                } catch {
                                    log("Failed to set audio session category. Error: \(error)")
                                }

                                playerObserver.addPeriodicTimeObserver()
                            }
                            .onDisappear {
                                playerObserver.removePeriodicTimeObserver()
                            }
                        //                    }
                        buttons(color: .accentColor)
                            .padding(.top)
                        Spacer()
                        
                    }
                    .navigationTitle("Trim your clip")
                    .padding()
                }
            }
        } else {
            Text("Video not loaded yet...")
        }
    }
    
    func buttons(color: Color) -> some View {
        return HStack {
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
                        .background(Color.blue.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Text("\(String(format: "%1.f", video.trimStart))s")
                    .foregroundColor(color)
                Spacer()
                
                Text("\(String(format: "%2.f", playerObserver.currentTime))s")
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(String(format: "%2.f", video.trimEnd))s")
                    .foregroundColor(color)
                
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
                        .background(Color.red.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                Text("Video not loaded yet...")
            }
        }
    }
    
    func seekTo(target: Double) {
        let newStartTime = CMTime(seconds: target, preferredTimescale: 600)
        playerObserver.player?.seek(to: newStartTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

}

//#Preview {
//    DetailedView(model: VideoJoinModel(), index: 0)
//}
