//
//  VideoEditor.swift
//  VideoJoin
//
//  Created by Anton Simonov on 7/4/24.
//

import Foundation
import AVFoundation

class VideoEditor {
    func createComposition(videos: [Video]) async throws -> (AVMutableComposition, [VideoTrack]) {
        let composition = AVMutableComposition()
        var tracks: [VideoTrack] = [VideoTrack]()
        
        guard let trackVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let trackAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw err("Unable to add video/audio track to composition")
        }

        var insertTime = CMTime.zero
        var fileSize: Int64 = 0
        
        var maxWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
        var highestFrameRate: Float64 = 0
        
        for video in videos {
            let asset = AVAsset(url: video.url)
            
            let start = CMTime(seconds: video.trimStart, preferredTimescale: 600)
            let duration = CMTime(seconds: video.trimEnd - video.trimStart, preferredTimescale: 600)
            
            guard let assetTrackVideo = try await asset.loadTracks(withMediaType: .video).first else {
                throw err("Error loading video track for \(video.url)")
            }
            
            try trackVideo.insertTimeRange(CMTimeRangeMake(start: start, duration: duration), of: assetTrackVideo, at: insertTime)
            
            // Load the track's properties
            let naturalSize = assetTrackVideo.naturalSize
            
            let preferredTransform = assetTrackVideo.preferredTransform
            log("Preffered transformation: \(preferredTransform)")

            maxWidth = max(maxWidth, naturalSize.width)
            maxHeight = max(maxHeight, naturalSize.height)
            
            let nominalFrameRate = assetTrackVideo.nominalFrameRate
            highestFrameRate = max(highestFrameRate, Double(nominalFrameRate))
            
            ///
            guard let assetTrackAudio = try await asset.loadTracks(withMediaType: .audio).first else {
                throw err("Error loading video track for \(video.url)")
            }
            try trackAudio.insertTimeRange(CMTimeRangeMake(start: start, duration: duration), of: assetTrackAudio, at: insertTime)
            tracks.append(VideoTrack(video: video, track: assetTrackVideo, start: insertTime, duration: duration, insertTime: insertTime))
            
            insertTime = CMTimeAdd(insertTime, duration)
            fileSize += video.size
        }

        return (composition, tracks)
    }
}

struct VideoTrack {
    var video: Video
    var track: AVAssetTrack
    var start: CMTime
    var duration: CMTime
    var insertTime: CMTime
}

