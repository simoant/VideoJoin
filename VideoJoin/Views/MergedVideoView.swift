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
    @FocusState private var filenameFocused: Bool
    @State var fileName = ""
    @State var isSaved = false

    var body: some View {
        VStack {
            PreviewVideoPlayer(model: model)
            Text("File size: \(displayFileSize(size: model.mergedVideo?.fileSize ?? 0))")
            
            TextField("Enter file name", text: $fileName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($filenameFocused)
                .padding()
                .onAppear {
                    fileName = model.defaultFilename() // Set default filename on appear
                }
                .onChange(of: fileName) { newValue in
                    model.mergedVideo?.fileName = fileName
                    //                            model.fileName = validateFilename(newValue) ? newValue : viewModel.fileName
                }
            HStack(spacing: 20) {
                Button(action: { self.exportToPhotoLibrary() })  {
                    Text("Save")
                        .bold()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(disabled() ?
                                    RoundedRectangle(cornerRadius: 10).fill(Color.gray) :
                                        RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                        .shadow(radius: 3)
                        .opacity(disabled() ? 0.5 : 1)
                }.disabled(disabled())
                
                Button(action: { self.share() })  {
                    Text("Share")
                        .bold()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(disabled() ?
                                    RoundedRectangle(cornerRadius: 10).fill(Color.gray) :
                                        RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                        .shadow(radius: 3)
                        .opacity(disabled() ? 0.5 : 1)
                }.disabled(disabled())
            }
            .padding(.top)
            .onAppear {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback)
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    log("Failed to set audio session category. Error: \(error)")
                }
            }
            .alert("Success", isPresented: $isSaved) {
                Button("OK", role: .cancel) {
                    isSaved = false
                    model.showMerge = false
                }
            } message: {
                Text("Video saved!")
            }
        }
    }
    
    private func disabled() -> Bool {
        return !model.validateFilename()
    }
    
    private func share() {
        if model.validateFilename() {
            model.isSaving = true
            Task {
                if let url = await model.saveLocally() {
                    log("Start sharing with url: \(url)")
                    DispatchQueue.main.async {
                        model.mergedVideo?.url = url
                        model.isSharing = true
                    }
                } else {
                    log("Url is empty")
                }
            }
        } else {
            model.errMsg = "File name is empty."
            model.isMergeError = true
        }
    }
        
    private func exportToPhotoLibrary() {
        if model.validateFilename() {
            Task {
                if self.model.mergedVideo?.url == nil {
                    if let url = await model.saveLocally() {
                        await model.exportToPhotoLibrary(url: url)
                        DispatchQueue.main.async {
                            isSaved = true
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    MergedVideoView(model: VideoJoinModel())
}
