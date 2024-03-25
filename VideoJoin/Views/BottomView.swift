//
//  BottomView.swift
//  VideoJoin
//
//  Created by Anton Simonov on 24/3/24.
//

import SwiftUI

struct BottomView: View {
    @StateObject var model: VideoJoinModel
    var body: some View {
        Section {
            HStack() {
                Spacer()
                HStack(spacing: 4) { // Reduce spacing as needed
                        Text("High Res")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    Toggle("", isOn: $model.hiRes) // Empty string for no default label
                            .labelsHidden() // Hide the default label space
                            .scaleEffect(0.8)
                            .padding(.trailing, -10)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                Spacer()
                Text("Free space: \(getAvailableDiskSpace())")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}

#Preview {
    BottomView(model: VideoJoinModel())
}
