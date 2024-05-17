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
    
    var description: some View {
        VStack {
            Text("No videos selected yet")
            
            if !(model.fullVersion) {
                Spacer()
                Text("The app is free, but you can support my work by subscribing :)")
                Spacer()
                Button("Buy me a coffee!") {
                    model.displayPaywall()
                }
            } else {
                Spacer()
                Text("Dear Subscriber! Thank you for your support!")
                Spacer()
            }
        }
    }
    
    var body: some View {
        Spacer()
        PhotosPicker(selection: $model.selected, selectionBehavior: .ordered,
                     matching: .videos, photoLibrary: .shared()) {
            ContentUnavailableView(label: {
                Label("No videos selected yet", systemImage: "video")
            }, description: {
                description
            })
            Spacer()
        }
        Spacer()
        
    }
}
