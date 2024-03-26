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
                if model.savingInProgress {
                    progressView
                } else {
                    PreviewVideoPlayer(model: model)
                        .edgesIgnoringSafeArea(.all)
                }

            } else {
                NavigationView {
                    if (model.savingInProgress) {
                        progressView
                        .navigationTitle("Merging...")
                        .navigationBarItems(
                            leading: Button(action: {
                                model.resetMerge()
                            }) {
                                Image(systemName: "xmark")
                            }
                        )
                    } else {
                        MergedVideoView(model: model)
                            .navigationTitle("Preview")
                            .navigationBarItems(
                                leading: Button(action: {
                                    model.resetMerge()
                                }) {
                                    Image(systemName: "xmark")
                                }
                            )
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $model.showShareView, content: {
            if let shareURL = model.mergedVideo?.url {
                ActivityView(activityItems: [shareURL], applicationActivities: nil)
            }
        })
        .alert("Error", isPresented: $model.isMergeError) {
            Button("OK", role: .cancel) {
                model.isMergeError = false
                model.resetMerge()
            }
        } message: {
            Text(model.errMsg)
        }
        .alert("Success", isPresented: $model.alertSaved) {
            Button("OK", role: .cancel) {
                model.alertSaved = false
            }
        } message: {
            Text("Video saved!")
        }

    }
    
    var progressView: some View {
        ProgressView(value: model.progress) {
            Text("Processing... \((Int(model.progress * 100)).formatted(.number))%" )
        }
        .progressViewStyle(.linear)
        .padding()
    }

    
}

#Preview {
    MergedView(model: VideoJoinModel())
}
