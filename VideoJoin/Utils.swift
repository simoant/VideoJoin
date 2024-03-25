//
//  Utils.swift
//  VideoJoin
//
//  Created by Anton Simonov on 13/2/24.
//

import Foundation
import Photos
import os.log

let logger = Logger(subsystem: "com.simoant.VideoJoin", category: "Main")


func log(_ msg: String) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm:ss.SSS"
    let currentTime = dateFormatter.string(from: Date())

    let thread = if Thread.current.isMainThread {
        "Main"
    } else {
        Thread.current.name ?? "N/A"
    }
    logger.info("\(currentTime):\(thread):\(msg)")
}

extension PHImageManager {
    func requestAVAssetAsync(forVideo asset: PHAsset, options: PHVideoRequestOptions?) async -> (avAsset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable: Any]?) {
        // Use withCheckedContinuation or withUnsafeContinuation to bridge the async/await gap
        await withCheckedContinuation { continuation in
            self.requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                // Resume the continuation by returning the result of the async operation
                continuation.resume(returning: (avAsset, audioMix, info))
            }
        }
    }
}

func validateFilename(_ filename: String) -> Bool {
    // Basic validation for filename (adjust regex according to your needs)
    // This pattern checks for valid characters and the .mov extension
    let pattern = "^[\\w\\-\\s\\:\\.]+$"
//    let pattern = "^[\\w\\-\\s\\:\\.]+\\.mov$"
    let result = filename.range(of: pattern, options: .regularExpression)
    return result != nil
}


func clearTemporaryFiles() {
    let fileManager = FileManager.default
    let tempDirectoryPath = NSTemporaryDirectory()
    
    do {
        let tempDirectoryURL = URL(fileURLWithPath: tempDirectoryPath, isDirectory: true)
        let temporaryFiles = try fileManager.contentsOfDirectory(at: tempDirectoryURL, includingPropertiesForKeys: nil, options: [])
        
        for fileURL in temporaryFiles {
            try fileManager.removeItem(at: fileURL)
            print("Deleted temporary file: \(fileURL.lastPathComponent)")
        }
    } catch {
        print("Failed to clear temporary files: \(error)")
    }
}

func getAvailableDiskSpace() -> String {
    let fileManager = FileManager.default
    do {
        let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
        if let freeSpace = attributes[.systemFreeSize] as? NSNumber {
            let bytesInKB = 1024
            let bytesInMB = bytesInKB * 1024
            let bytesInGB = bytesInMB * 1024
            let freeSpaceGB = Double(truncating: freeSpace) / Double(bytesInGB)
            return String(format: "%.2f GB", freeSpaceGB)
        } else {
            return "Could not retrieve free space"
        }
    } catch {
        return "Error retrieving free space: \(error.localizedDescription)"
    }
}

func renameFileInTempDirectory(from oldName: String, to newName: String) throws -> URL {
    let fileManager = FileManager.default
    let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
    
    let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectoryURL, includingPropertiesForKeys: nil, options: [])
    
    for fileURL in tempFiles {
        if fileURL.lastPathComponent == oldName {
            let newFileURL = tempDirectoryURL.appendingPathComponent(newName)
            try fileManager.moveItem(at: fileURL, to: newFileURL)
            print("File renamed from \(oldName) to \(newName)")
            return newFileURL
        }
    }
    throw NSError(domain: "VideoJoinError", code: -1, userInfo: [NSLocalizedDescriptionKey: "File \(oldName) not found in temporary directory."])
}

func displayFileSize(size: Int64) -> String {
    return "\(String(format: "%.0f", Float(size)/(1024*1024))) Mb"
}

func err(_ msg: String) -> DataError {
    return DataError.unknown(message: msg)
}

func trimmed(_ str: String, _ startInclude: Int, _ endInclude: Int) -> String{
    let subst = "..."
    return if str.count > startInclude + endInclude + subst.count {
        "\(str.prefix(startInclude))\(subst)\(str.suffix(endInclude))"
    } else {
        str
    }
}
