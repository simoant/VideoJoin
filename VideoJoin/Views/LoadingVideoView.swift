//
//  LoadingVideoView.swift
//  VideoJoin
//
//  Created by Anton Simonov on 24/3/24.
//

import SwiftUI

struct LoadingVideoView: View {
    @StateObject var model: VideoJoinModel
    var index: Int
    var body: some View {
        if model.videos.count > index {
            ProgressView(value: model.videos[index].downloadProgress)  {
                Text("Loading: \(Int(model.videos[index].downloadProgress * 100))%")
                    .font(.footnote)
                    .foregroundColor(.primary)
            }
            .cornerRadius(5)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 200 : 150,
                   height: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 100,
                   alignment: .center) // Adjust the size based on the device
        }
    }
}

#Preview {
    LoadingVideoView(model: VideoJoinModel(), index: 0)
}
