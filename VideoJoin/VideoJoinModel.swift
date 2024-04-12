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
import RevenueCat

struct VideoItem: Identifiable {
    let id: String
    
    var downloadProgress: Double = 0.0
    var isValid = true
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
    var videoComposition: AVMutableVideoComposition?
    var fileSize: Int64?
    var fileName: String?
    var hasEdits: Bool = false
}

class VideoJoinModel: ObservableObject {
    @Published var isError  = false
    @Published var isMergeError = false
    @Published var errMsg = ""
    @Published var progress: Double = 0.0
    @Published var exportSession: AVAssetExportSession? = nil
    @Published var task: Task<(), Never>? = nil
    
    @Published var showMergeView = false
    @Published var savingInProgress = false
    @Published var showShareView = false
    @Published var showPurchaseView = false
    @Published var alertSaved = false
    
    @Published var selected = [PhotosPickerItem]() {
        didSet {
            log("didSet selected: \(selected)")
            
        }
    }
    @Published var hiRes = true
    @Published var videos = [VideoItem]()
    @Published var mergedVideo: MergedVideo? = nil
    
    private var revCat = RevenueCatManager()
    @Published var showPaywall = false
    @Published var fullVersion = true
    
    let maxFreeVideos = 2
    
    @MainActor
    func displayPaywall() {
        clearSelectedNew()
        showPaywall = true
    }
    
    func canAddVideos() async throws -> Bool {
        do { 
            let purchased = try await hasActiveSubscription()
            if selected.count + videos.count > maxFreeVideos && !purchased {
                return false
            }
            return true
        } catch {
            handle(error)
            return false
        }
    }
    
    func hasActiveSubscription() async throws -> Bool {
        return try await revCat.hasActiveSubscription()
    }
    
    @MainActor
    func updateVersionStatus() async {
        do {
            self.fullVersion = try await self.hasActiveSubscription()
        } catch {
            handle(error)
        }
    }
    
    func addVideos() {
        if !selected.isEmpty {
            Task {
                do {
                    log("Selected videos: \(selected.count)")
                    
                    let identifiers = self.selected.compactMap(\.itemIdentifier)
                    
                    if (try await canAddVideos() == false) {
                        await displayPaywall()
                        log("Selected videos after paywall: \(selected.count)")
                        return
                    }
                        
                    await self.clearSelected()
                
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: fetchOptions)
                    log("Fetch result: \(fetchResult)")
                    
                    if identifiers.count != fetchResult.count {
                        throw err(
                            "Failed to get \(identifiers.count - fetchResult.count) videos from Photo library. Please check that you have granted access to them.")
                    }

                    // Use a TaskGroup to concurrently fetch and process each video
                    await withTaskGroup(of: (Video?, Int).self) { group in
                        log("inside group task \(self.videos.count)")

                        for i in 0..<fetchResult.count {
                            let phAsset = fetchResult.object(at: i)
                            let idx = await self.addVideoItem(videoItem: VideoItem(id: phAsset.localIdentifier))
                        
                            group.addTask {
                                do {
                                    let phAsset = fetchResult.object(at: i)
                                    let video = try await self.getVideo(phAsset: phAsset, progressHandler: { progress in
                                        Task { await self.setDownloadProgress(progress: progress, i: idx) }
                                    })
                                    return (video, idx)
                                }
                                catch {
                                    self.handle(error)
                                    return (nil, idx)
                                }
                            }
                        }
                        for await (video, i) in group {
                            if  let video = video {
                                await self.setVideo(video: video, i: i)
                            } else {
                                log("Videos is empty")
                                await self.setInvalidVideo(i: i)
                            }
//                            guard let video = video else {
//                                log("Videos is empty")
//                                videos.remove(at: i)
//                                continue
//                            }
                            
                        }
                    }
                } catch {
                    handle(error)
                }
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
            throw err("Could not access some of selected videos. Some media types like slow motion videos are not supported yet.")
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
            Task { await MainActor.run { progressHandler(progress) } }
        }
        
        let (asset, _, _) = await PHImageManager.default().requestAVAssetAsync(forVideo: phAsset, options: options)
        return asset
    }
    
    func resetMerge() {
        log("Reset merge")
        task?.cancel()
        showMergeView = false
        mergedVideo = nil
    }
    
    func merge() {
        self.progress = 0.0
        
        func isVideoUpsideDown(_ transform: CGAffineTransform) -> Bool {
            return transform.a == -1.0 && transform.d == -1.0
        }
        
        func allVertical(tracks: [VideoTrack]) -> Bool {
            return tracks.allSatisfy({ track in
                isRotated90(track: track)
            })
        }
        
        @Sendable func isRotated90(track: VideoTrack) -> Bool {
            return track.track.preferredTransform.b == 1.0 || track.track.preferredTransform.c == -1.0
        }

        task = Task {
            
            do {
                let composition = AVMutableComposition()
                guard let trackVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                      let trackAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    throw err("Unable to add video/audio track to composition")
                }
                
                var insertTime = CMTime.zero
                var fileSize: Int64 = 0
                
                var maxWidth: CGFloat = 0
                var maxHeight: CGFloat = 0
                var highestFrameRate: Float64 = 0
                var hasEdits = false
                
                //  Create composition
                let videos = self.videos.compactMap(\.video)
                var tracks: [VideoTrack] = [VideoTrack]()
                for video in videos {
                    let asset = AVAsset(url: video.url)
                    
                    let start = CMTime(seconds: video.trimStart, preferredTimescale: 600)
                    let duration = CMTime(seconds: video.trimEnd - video.trimStart, preferredTimescale: 600)
                    
                    guard let assetTrackVideo = try await asset.loadTracks(withMediaType: .video).first else {
                        let _date = video.date?.formatted(.dateTime.day().month(.defaultDigits).year(.twoDigits).hour().minute())
                        throw err("Error loading video track for video \(_date)")
                    }
                    
                    try trackVideo.insertTimeRange(CMTimeRangeMake(start: start, duration: duration), of: assetTrackVideo, at: insertTime)
                    
                    // Load the track's properties
                    let naturalSize = assetTrackVideo.naturalSize
                    print("Natural size", naturalSize)
                    
                    let preferredTransform = assetTrackVideo.preferredTransform
                    log("Preffered transformation: \(preferredTransform)")

                    maxWidth = max(maxWidth, naturalSize.width)
                    maxHeight = max(maxHeight, naturalSize.height)
                    
                    let nominalFrameRate = assetTrackVideo.nominalFrameRate
                    highestFrameRate = max(highestFrameRate, Double(nominalFrameRate))
                    
                    guard let assetTrackAudio = try await asset.loadTracks(withMediaType: .audio).first else {
                        throw err("Error loading audio track for \(video.url)")
                    }
                    try trackAudio.insertTimeRange(CMTimeRangeMake(start: start, duration: duration), of: assetTrackAudio, at: insertTime)
                    tracks.append(VideoTrack(video: video, track: assetTrackVideo, start: start, duration: duration, insertTime: insertTime))
                    
                    insertTime = CMTimeAdd(insertTime, duration)
                    fileSize += video.size
                }
                
                log("Composition natural size: \(composition.naturalSize)")
                log("Max size: \(maxWidth) \(maxHeight)")
                
                // MARK: check if all videos al vertical
                let allVertical = allVertical(tracks: tracks)
                
                if allVertical {
                    composition.naturalSize = CGSize(width: composition.naturalSize.height, height: composition.naturalSize.width)
                }
                
                // MARK: create video editing composition
                let videoComposition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: composition)
                var instructions = [AVMutableVideoCompositionInstruction]()
                for videoTrack in tracks {
                    let preferredTransform = videoTrack.track.preferredTransform
                    let naturalSize = videoTrack.track.naturalSize
                    
                    let instruction = AVMutableVideoCompositionInstruction()
                    instruction.timeRange = CMTimeRange(start: videoTrack.insertTime, duration: videoTrack.duration)
                    
                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: trackVideo)
                    
                    if allVertical {
                        print("allVertical")
                        let scaleFactor = min(maxWidth / naturalSize.width, maxHeight / naturalSize.height)
                        var finalTransform = preferredTransform
                        finalTransform = finalTransform
                            .scaledBy(x: scaleFactor, y: scaleFactor)
                        print(preferredTransform)
                        print(finalTransform)
                        layerInstruction.setTransform(finalTransform, at: videoTrack.start)
                        hasEdits = true
                    } else if isRotated90(track: videoTrack) { // Video is rotated 90° or 270°
                        print("rotated")
                        let verticalVideoSize = naturalSize
                        let verticalHeight = verticalVideoSize.width
                        let verticalWidth = verticalVideoSize.height
                        print(verticalHeight, verticalWidth)

                        let scaleFactorResolution = maxWidth / naturalSize.width
                        let scaleFactor = (verticalWidth * scaleFactorResolution) / (maxWidth / scaleFactorResolution)
                        
                        let translateX = (maxWidth + (verticalWidth * scaleFactor)) / 2
                        var finalTransform = preferredTransform
                        finalTransform.ty = 0
                        finalTransform.tx = translateX
                        finalTransform = finalTransform.scaledBy(x: scaleFactor, y: scaleFactor) //.translatedBy(x: translateX, y: 0)
                        print(preferredTransform)
                        print(finalTransform)

                        // Apply the transform to the layer instruction
                        layerInstruction.setTransform(finalTransform, at: videoTrack.start)
                        hasEdits = true
                    } else {
                        print("Normal")
                        let scaleFactor = (maxWidth / naturalSize.width)
                        let finalTransform = preferredTransform.scaledBy(x: scaleFactor, y: scaleFactor)
                        
                        print(preferredTransform)
                        print(finalTransform)
                        
                        layerInstruction.setTransform(finalTransform, at: videoTrack.start)
                    }

                    instruction.layerInstructions = [layerInstruction]
                    instructions.append(instruction)
                }
                
                print("Natural size", composition.naturalSize)
                print("Width", maxWidth, "Height", maxHeight)
                
                videoComposition.instructions = instructions
                videoComposition.renderSize = if allVertical {
                    CGSize(width: maxHeight, height: maxWidth)
                } else {
                    CGSize(width: maxWidth, height: maxHeight)
                }
                videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(highestFrameRate))

//                log("Video composition instructions: \(videoComposition.instructions)")
                log("Video composition renderSize: \(videoComposition.renderSize)")
                log("Video composition frameDuration: \(videoComposition.frameDuration)")

                await self.setMergedVideo(
                    mergedVideo: MergedVideo(
                        url: nil, composition: composition, videoComposition: videoComposition, fileSize: fileSize, fileName: self.defaultFilename(), hasEdits: hasEdits
                    )
                )
                await MainActor.run {
                    self.showMergeView = true
                }

            } catch {
                self.handle(error)
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    func exportToPhotoLibrary(url: URL) async {
        do {
            let authorized = await requestAuthorization()
            guard authorized else {
                throw err("Photos library access not authorized")
            }
            
            try await withCheckedThrowingContinuation { continuation in
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { success, error in
                    if success {
                        continuation.resume()
                    } else if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: err("Unknown error occurred while exporting video to Photo library"))
                    }
                }
            }
            log("Exported to Photo library")
        } catch {
            handle(error)
        }
    }
    
    func saveLocally(timer: ProgressModel) async -> URL? {
        do {
            await setSavingInProgress()
            
            // Export to disk
            guard let composition = mergedVideo?.composition else {
                throw err("Videos composition is empty")
            }

            guard let videoComposition = mergedVideo?.videoComposition else {
                throw err("Videos videoComposition is empty")
            }
            
            let presetName = if mergedVideo?.hasEdits == true {
                AVAssetExportPresetHEVCHighestQuality
            } else {
                AVAssetExportPresetPassthrough
            }
            print("Export preset", presetName)
            guard let exportSession = AVAssetExportSession(asset: composition, presetName: presetName) else {
                throw err("Could not create export session")
            }
            
            guard let fileName = mergedVideo?.fileName else {
                throw err("File name is empty")
            }
            
            clearTemporaryFiles()
            
            let outputFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName + ".mov")
            
            exportSession.outputURL = outputFileURL
            exportSession.videoComposition = videoComposition
//            print("Video Composiition:", videoComposition.instructions)
            exportSession.outputFileType = .mov
            log("Output url: \(outputFileURL)")
            
            await setExportSession(exportSession: exportSession)
            
            // Track progress
            await timer.startTrackingProgress()
            
            await exportSession.export()
            switch exportSession.status {
            case .failed, .cancelled:
                if let error = exportSession.error {
                    throw err("Sorry, something when wrong:\(error.localizedDescription)")
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
                await setMergedVideoFileSize(fileSize: Int64(fileSize))
            } else {
                log("Could not fetch file size")
            }
            
            await finishSaving(url: outputFileURL)
            return outputFileURL
        } catch {
            handle(error)
            await finishSaving(url: nil)
            return nil
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
        videos.filter({$0.video == nil && $0.isValid}).count == 0
    }
    
    func handle(_ error: Error) {
        Task {
            await MainActor.run {
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
                if self.showMergeView {
                    self.isMergeError = true
                } else {
                    self.isError = true
                }
            }
        }
    }
    
    func validateFilename() -> Bool {
        // Basic validation for filename (adjust regex according to your needs)
        // This pattern checks for valid characters and the .mov extension
        let pattern = "^[\\w\\-\\s\\:\\.]+$"
    //    let pattern = "^[\\w\\-\\s\\:\\.]+\\.mov$"
        guard let filename = mergedVideo?.fileName else { return false }
        let result = filename.range(of: pattern, options: .regularExpression)
        return result != nil
    }

    
    func longOp() {
        DispatchQueue.main.async {
            self.progress = 0.0
            self.showMergeView = true
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
                    self.showMergeView = false
                    self.isError = true
                    self.errMsg = error.localizedDescription
                }
            }
            DispatchQueue.main.async {
                self.showMergeView = false
            }
        }
    }
    
    @MainActor
    func clear() {
        self.videos.removeAll()
    }

    @MainActor
    func clearSelected() {
        self.selected.removeAll()
    }

    @MainActor
    func clearSelectedNew() {
        let ids: [String] = videos.compactMap { $0.id }
        
        selected = selected.filter { item in
            if let id = item.itemIdentifier {
                return ids.contains(id)
            }
            return false
        }
    }
    
    @MainActor
    func setVideo(video: Video, i: Int) {
        self.videos[i].video = video
    }

    @MainActor
    func setInvalidVideo(i: Int) {
        self.videos[i].isValid = false
    }
    
    @MainActor
    func addVideoItem(videoItem: VideoItem) -> Int {
        self.videos.append(videoItem)
        return videos.count - 1
    }

    @MainActor
    func setDownloadProgress(progress: Double, i: Int) {
        self.videos[i].downloadProgress = progress
    }
    
    @MainActor
    func raiseAlertSaved() {
        self.alertSaved = true
    }
    
    @MainActor
    func displayShareView() {
//        mergedVideo?.url = url
        self.showShareView = true
    }
    
    @MainActor
    func setMergedVideo(mergedVideo: MergedVideo) {
        self.mergedVideo = mergedVideo
    }
    
    @MainActor
    func setSavingInProgress() {
        self.savingInProgress = true
    }
    
    @MainActor
    func setExportSession(exportSession: AVAssetExportSession) {
        self.exportSession = exportSession
    }
    
    @MainActor
    func setMergedVideoFileSize(fileSize: Int64) {
        self.mergedVideo?.fileSize = fileSize
    }
    
    @MainActor
    func finishSaving(url: URL?) {
        self.savingInProgress = false
        self.mergedVideo?.url = url
    }

}
