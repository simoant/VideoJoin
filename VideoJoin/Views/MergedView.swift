//
//  MergedView.swift
//  VideoJoin
//
//  Created by Anton Simonov on 24/3/24.
//

import SwiftUI

struct MergedView: View {
    @StateObject var model: VideoJoinModel
    @StateObject var orientation: OrientationManager = OrientationManager()
    var body: some View {
        VStack {
            if orientation.isLandscape {
                if model.isSaving {
                    progressView
                } else {
                    PreviewVideoPlayer(model: model)
                        .edgesIgnoringSafeArea(.all)
                }

            } else {
                NavigationView {
                    if (model.isSaving) {
                        progressView
                        .navigationTitle("Merging...")
                        .navigationBarItems(
                            leading: Button(action: {
                                model.task?.cancel()
                                model.showMerge = false
                            }) {
                                Image(systemName: "xmark")
                            }
                        )
                    } else {
                        MergedVideoView(model: model)
                            .navigationTitle("Preview")
                            .navigationBarItems(
                                leading: Button(action: {
                                    model.task?.cancel()
                                    model.showMerge = false
                                }) {
                                    Image(systemName: "xmark")
                                }
                            )
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $model.isSharing, content: {
            if let shareURL = model.mergedVideo?.url {
                ActivityView(activityItems: [shareURL], applicationActivities: nil)
            }
        })
        .alert("Error", isPresented: $model.isMergeError) {
            Button("OK", role: .cancel) {
                model.isMergeError = false
                model.showMerge = false
            }
        } message: {
            Text(model.errMsg)
        }
    }
    
    var progressView: some View {
        ProgressView(value: model.progress) {
            Text("Generating video... \((model.progress * 100).formatted(.number))%" )
        }
        .progressViewStyle(.linear)
        .padding()
    }

    
}

#Preview {
    MergedView(model: VideoJoinModel())
}
