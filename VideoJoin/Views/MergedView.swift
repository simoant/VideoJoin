//
//  MergedView.swift
//  VideoJoin
//
//  Created by Anton Simonov on 24/3/24.
//

import SwiftUI

struct MergedView: View {
    @StateObject var model: VideoJoinModel
    var body: some View {
        NavigationView {
            if (model.mergedVideo == nil) {
                ProgressView(value: model.progress) {
                    Text("Merging... \((model.progress * 100).formatted(.number))%" )
                }
                .progressViewStyle(.linear)
                .padding()
                .navigationBarItems(
                    leading: Button(action: {
                        model.task?.cancel()
                        model.showMerge = false
                    }) {
                        Image(systemName: "xmark")
                    }
                )
                .navigationTitle("Merging...")
            } else {
                MergedVideoView(model: model)
            }
        }
        .alert("Error", isPresented: $model.isMergeError) {
            Button("OK", role: .cancel) {
                model.isMergeError = false
                model.showMerge = false
            }
        } message: {
            Text(model.errMsg)
        }
        .onAppear(perform: {
            log("Appeared")
            model.mergeDisplayed = true
        })
        .onDisappear(perform: {
            model.mergeDisplayed = false
            log("Disappeared")
        })
    }
}

#Preview {
    MergedView(model: VideoJoinModel())
}
