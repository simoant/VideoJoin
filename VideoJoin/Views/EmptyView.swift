//
//  EmptyView.swift
//  VideoJoin
//
//  Created by Anton Simonov on 23/3/24.
//

import SwiftUI
import PhotosUI
import SwiftData


struct EmptyView: View {
    @StateObject var model: VideoJoinModel
    var body: some View {
        Spacer()
        PhotosPicker(selection: $model.selected, selectionBehavior: .ordered,
                     matching: .videos, photoLibrary: .shared()) {
            ContentUnavailableView("Please select some videos", systemImage: "video",
                                   description:  Text("No videos selected yet")
            )
            Spacer()
        }
        Spacer()
    }
}
