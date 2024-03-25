//
//  VideoView.swift
//  VideoJoin
//
//  Created by Anton Simonov on 24/3/24.
//

import SwiftUI

struct VideoView: View {
    @StateObject var model: VideoJoinModel
    var index: Int
    var body: some View {
        HStack(alignment: .center) {
            Image(uiImage: (model.videos[index].video?.image ?? UIImage(systemName: "video"))!)
                .resizable()
                .scaledToFit()
                .cornerRadius(5)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 200 : 150,
                       maxHeight: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 100,
                       alignment: .center) // Adjust the size based on the device
            
            VStack(alignment: .leading, spacing: 5) {
                if let date = model.videos[index].video?.date {
                    HStack {
                        Image(systemName: "calendar") // Icon for date
                            .foregroundColor(.secondary)
                        Text(date, format: .dateTime.day().month(.defaultDigits).year(.twoDigits).hour().minute())
                            .bold()
                            .lineLimit(1)
                    }
                }

                Group {
                    HStack {
                        Image(systemName: "clock") // Icon for length
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", (model.videos[index].video?.duration ?? 0)))s")
                            .lineLimit(1)
                    }
                    if let size = model.videos[index].video?.size {
                        HStack {
                            Image(systemName: "externaldrive.fill") // Icon for length
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.0f", Float(size)/(1024*1024))) Mb")
                                .lineLimit(1)
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "ruler") // Icon for length
                        .foregroundColor(.secondary)
                        .scaledToFit()
                    if let width = model.videos[index].video?.resolution.width,
                       let height = model.videos[index].video?.resolution.height {
                        Text("\(Int(width)) x \(Int(height))")
                            .lineLimit(1)
                    } else {
                        Text("N/A")
                    }
                    
                }
            }
            
        }.font(.footnote)
            .foregroundColor(.primary)
            .layoutPriority(1)

        }

    }


#Preview {
    VideoView(model: VideoJoinModel(), index: 0)
}
