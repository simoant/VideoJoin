//
//  VideoJoinModel.swift
//  VideoJoin
//
//  Created by Anton Simonov on 23/3/24.
//

import Foundation
import Photos
import PhotosUI
import SwiftUI
import UIKit

struct VideoItem: Identifiable {
    let id: String
    
    var downloadProgress: Double = 0.0
    var video: Video? = nil
}

struct Video {
    let phAsset: PHAsset
    let url: URL
    let date: Date?
    let duration: Double
    let image: UIImage
    let size: Int64
    var trimStart: Double
    var trimEnd: Double
    let resolution: CGSize
}

struct MergedVideo {
    var url: URL?
    var composition: AVMutableComposition?
    let fileSize: Int64?
    var fileName: String?
}

class VideoJoinModel: ObservableObject {
    @Published var isError  = false
    @Published var isMergeError = false
    @Published var errMsg = ""
    @Published var progress: Double = 0.0
    @Published var task: Task<(), Never>? = nil
    @Published var mergeDisplayed = false
    
    @Published var showMerge = false
    
    @Published var selected = [PhotosPickerItem]()
    @Published var hiRes = true
    @Published var videos = [VideoItem]()
    @Published var mergedVideo: MergedVideo? = nil
    
    func addVideos() {
        if !selected.isEmpty {
            do {
                log("Selected videos: \(selected.count)")
                let identifiers = selected.compactMap(\.itemIdentifier)
                                
                for i in 0..<identifiers.count {
                    self.videos.append(VideoItem(id: identifiers[i]))
                }
            
                Task {
                    do {
                        let fetchOptions = PHFetchOptions()
                        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: fetchOptions)
                        log("Fetch result: \(fetchResult)")
                        if selected.count != fetchResult.count {
                            throw err(
                                "Failed to get \(selected.count - fetchResult.count) videos from Photo library. Please check that you have granted access to them.")
                        }

                        // Use a TaskGroup to concurrently fetch and process each video
                        await withTaskGroup(of: (Video?, Int).self) { group in
                            log("inside grouo task \(self.videos.count)")
                            for i in 0..<self.videos.count {
                                group.addTask {
                                    do {
                                        let phAsset = fetchResult.object(at: i)
                                        let video = try await self.getVideo(phAsset: phAsset, progressHandler: { progress in
                                            self.videos[i].downloadProgress = progress
                                        })
                                        return (video, i)
                                    }
                                    catch {
                                        self.handle(error)
                                        return (nil, i)
                                    }
                                }
                            }
                            for await (video, i) in group {
                                if video == nil {
                                    log("Videos is empty")
                                }
                                DispatchQueue.main.async {
                                    if let video = video {
                                        self.videos[i].video = video
                                    }
                                }
                            }
                        }
                    } catch {
                        handle(error)
                    }
                }
            } catch {
                handle(error)
            }
        }
    }
    
    private func getVideo(phAsset: PHAsset, progressHandler: @escaping (_ progress: Double) -> Void) async throws -> Video? {
        let captureDate = phAsset.creationDate
        let length = phAsset.duration // Duration in seconds
        //                        print("AVAsset", videoItem.avAsset)
        let asset = await self.getAvAsset(phAsset, progressHandler: progressHandler)
        log("AvAsset: \(asset)")
        guard let urlAsset = asset as? AVURLAsset else {
            log("Could not access some of selected videos. Please make sure you have granted access to Photo library.")
            return nil
        }
        let image = try self.getThumbnail(asset: urlAsset)
        let resolution = urlAsset.tracks(withMediaType: .video).first?.naturalSize ?? .zero
        let resources = try urlAsset.url.resourceValues(forKeys: [.fileSizeKey])
        let size = Int64(resources.fileSize ?? -1)
        log("file size: \(size) \(size/(1024*1024))")
        let video = Video(phAsset: phAsset, url: urlAsset.url, date: captureDate, duration: length, image: image, size: size, trimStart: 0.0, trimEnd: length, resolution: resolution)
        return video

    }
    
    private func getThumbnail(asset: AVAsset) throws ->  UIImage {
        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImageGenerator.appliesPreferredTrackTransform = true
        let timestamp = CMTime(seconds: 1, preferredTimescale: 60)
        
        let imageRef = try assetImageGenerator.copyCGImage(at: timestamp, actualTime: nil)
        let image = UIImage(cgImage: imageRef)
        return image
    }
    
    private func getAvAsset(_ phAsset: PHAsset,  progressHandler: @escaping (_ progress: Double) -> Void) async -> AVAsset? {
        let options: PHVideoRequestOptions = PHVideoRequestOptions()
        if self.hiRes {
            options.version = .current
            options.deliveryMode = .highQualityFormat
        } else {
            options.deliveryMode = .automatic
        }
        options.isNetworkAccessAllowed = true
        options.progressHandler = { progress, error, stop, info in
            // Update UI with download progress if needed
            if let e = error {
                self.handle(e)
                return
            }
            DispatchQueue.main.async {
                progressHandler(progress)
            }
        }
        
        let (asset, _, _) = await PHImageManager.default().requestAVAssetAsync(forVideo: phAsset, options: options)
        return asset
    }
    
    func merge() {
        self.progress = 0.0
        self.showMerge = true

        task = Task {
            let composition = AVMutableComposition()
            do {
                //        throw err("Test")
                guard let trackVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                      let trackAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    throw err("Unable to add video/audio track to composition")
                }
//                throw err("Test")

                
                var insertTime = CMTime.zero
                
                //  Create composition
                for video in self.videos.compactMap(\.video) {
                    let asset = AVAsset(url: video.url)
                    
                    let start = CMTime(seconds: video.trimStart, preferredTimescale: 600)
                    let duration = CMTime(seconds: video.trimEnd - video.trimStart, preferredTimescale: 600)
                    
                    // Handle video track
                    if let assetTrackVideo = try await asset.loadTracks(withMediaType: .video).first {
                        try trackVideo.insertTimeRange(CMTimeRangeMake(start: start, duration: duration), of: assetTrackVideo, at: insertTime)
                        
                    } else { throw err("Failed loading video tracks") }
                    
                    // Handle audio track
                    if let assetTrackAudio = try await asset.loadTracks(withMediaType: .audio).first {
                        try trackAudio.insertTimeRange(CMTimeRangeMake(start: start, duration: duration), of: assetTrackAudio, at: insertTime)
                    } else { throw err("Failed loading video tracks") }
                    
                    insertTime = CMTimeAdd(insertTime, duration)
                }
                
                DispatchQueue.main.async {
                    self.mergedVideo = MergedVideo(url: nil, composition: composition, fileSize: nil, fileName: self.defaultFilename()) // Return both URL and file size
                }
            } catch {
                self.handle(error)
            }
        }
    }
    
    func save() {
        Task {
            do {
                // Export to disk
                
                guard let composition = mergedVideo?.composition else {
                    throw err("Videos composition is empty")
                }
                
                guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
                    throw err("Could not create export session")
                }
                
                guard let fileName = mergedVideo?.fileName else {
                    throw err("File name is empty")
                }
                
                let outputFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName + ".mov")
                
                exportSession.outputURL = outputFileURL
                exportSession.outputFileType = .mov
                let fileSize = try await exportSession.estimatedOutputFileLengthInBytes
                log("Output url: \(outputFileURL)")
                log("Output url: \(outputFileURL)")
                
                // Track progress
                let timerHolder = TimerHolder()
                DispatchQueue.main.async {
                    timerHolder.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                        log("Timer")
                        DispatchQueue.main.async {
                            self.progress = Double(exportSession.progress)
                            log("Updating progress \(exportSession.progress)")
                            if exportSession.progress >= 1.0 || exportSession.status != .exporting {
                                timerHolder.invalidate()
                            }
                        }
                    }
                    // Ensure the timer is added to the main run loop and configured for common modes to allow it to fire while scrolling UI elements.
                    RunLoop.main.add(timerHolder.timer!, forMode: .common)
                }
                
                await exportSession.export()
                switch exportSession.status {
                case .failed, .cancelled:
                    if let error = exportSession.error {
                        throw err("Failed saving:\(error.localizedDescription)")
                    } else {
                        throw err("Sorry, something when wrong with saving merged video to temporary folder")
                    }
                default:
                    break
                }
                
                log("Exported")
                // Get file size
                let attributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
                if let fileSize = attributes[.size] as? UInt64 {
                    DispatchQueue.main.async {
                        self.mergedVideo = MergedVideo(url: outputFileURL, fileSize: Int64(fileSize)) // Return both URL and file size
                    }
                } else {
                    throw err("Could not fetch file size")
                }
            } catch {
                handle(error)
            }
        }

    }
    
    func defaultFilename() -> String {
        let maxDate = videos
            .compactMap(\.video)
            .filter({$0.date != nil}).max(by: {v1, v2 in v1.date! > v2.date! })?.date ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: maxDate)
        return dateString
    }
    
    func allLoaded() -> Bool {
        return true
    }
    
    func handle(_ error: Error) {
        DispatchQueue.main.async {
            // First, try to cast the error to the specific type we're interested in.
            if let dataError = error as? DataError {
                // Handle the specific cases of DataError
                switch dataError {
                case .unknown(let msg):
                    // Set the error message and log it.
                    // Make sure `errMsg` is declared somewhere accessible in this scope.
                    self.errMsg = msg
                    log(msg) // Ensure there's a function or method `log` accepting a String.
                    // Add other cases for DataError here if needed.
                }
            } else {
                // If the error is not a DataError, handle the default case.
                self.errMsg = error.localizedDescription
                // Here `msg` should be replaced with `errMsg` or use `error.localizedDescription` directly.
                log(self.errMsg) // Similarly, ensure 'errMsg' is accessible and 'log' can be called like this.
            }
//            self.showMerge = false
            if self.showMerge {
                self.isMergeError = true
            } else {
                self.isError = true
            }
        }
    }
    
    func longOp() {
        DispatchQueue.main.async {
            self.progress = 0.0
            self.showMerge = true
        }
        
        let totalSteps = 100
        task = Task {
            do {
                for step in 1...totalSteps {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50 milliseconds per step
                    
                    // Ensure we're not updating state for a cancelled task.
                    guard !Task.isCancelled else { return }
                    
                    if step > 50 {
                        throw DataError.unknown(message: "Test Error")
                    }
                    
                    DispatchQueue.main.async {
                        self.progress = Double(step)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showMerge = false
                    self.isError = true
                    self.errMsg = error.localizedDescription
                }
            }
            DispatchQueue.main.async {
                self.showMerge = false
            }
        }
    }
    
    class TimerHolder {
        var timer: Timer?

        func invalidate() {
            timer?.invalidate()
            timer = nil
        }
    }
}