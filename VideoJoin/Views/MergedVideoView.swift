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
    @StateObject var timer: ProgressModel
//    @State var size: CGSize
//    @State var safeArea: EdgeInsets
    @FocusState private var filenameFocused: Bool
    @State var fileName = ""
    @State var width = 0.0
    @State var height = 0.0

    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            ZStack {
                GeometryReader { geometry in
                    Color.clear // Invisible view just to calculate sizes
                        .onAppear {
                            // Calculate the video size and scale here but do not place the video player inside
                            let videoSize = model.mergedVideo?.composition?.naturalSize ?? CGSize(width: 0, height: 0)
                            let scale = min(geometry.size.width / videoSize.width, geometry.size.height / videoSize.height)
                            height = videoSize.height * scale
                            width = videoSize.width * scale
                            print(height, width, videoSize, scale, geometry.size)
                        }
                }
                
                PreviewVideoPlayer(model: model)
                    .cornerRadius(8)
                    .shadow(radius: 5)
                    .frame(width: width, height: height, alignment: .bottom)
            }
            
            Text("Estimated file size: \(displayFileSize(size: model.mergedVideo?.fileSize ?? 0))")
                .font(.subheadline)
            
            Spacer()
            TextField("Enter file name", text: $fileName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($filenameFocused)
//                    .padding()
                .font(.subheadline)
                .foregroundColor(.accentColor)
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
        }
    }
    
    
    private func disabled() -> Bool {
        return !model.validateFilename()
    }
    
    private func share() {
        if model.validateFilename() {
            model.savingInProgress = true
            Task(priority: .userInitiated) {
                if let url = await model.saveLocally(timer: self.timer) {
                    log("Start sharing with url: \(url)")
                    model.displayShareView()
                } else {
                    log("Url is empty")
                }
            }
        } else {
            model.errMsg = "Invalid file name."
            model.isMergeError = true
        }
    }
        
    private func exportToPhotoLibrary() {
        if model.validateFilename() {
            Task {
                log("URL in export \(self.model.mergedVideo?.url)")
                if let url = self.model.mergedVideo?.url {
                    log("URL is not empty, exporting")
                    await model.exportToPhotoLibrary(url: url)
                    model.raiseAlertSaved()
                } else {
                    log("URL is empty, saving locally")
                    if let url = await model.saveLocally(timer: self.timer) {
                        await model.exportToPhotoLibrary(url: url)
                        model.raiseAlertSaved()
                    }
                }
            }
        } else {
            model.errMsg = "Invalid file name."
            model.isMergeError = true
        }
    }
}

#Preview {
    MergedVideoView(model: VideoJoinModel(), timer: ProgressModel(progress: 0.0, progressSupplier: {0.0}))
}
