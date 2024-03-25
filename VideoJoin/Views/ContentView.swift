//
//  ContentView.swift
//  VideoJoin
//
//  Created by Anton Simonov on 23/3/24.
//

import SwiftUI
import PhotosUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showingPicker = false
    @StateObject var model = VideoJoinModel()

    var body: some View {
        NavigationStack {
            if model.videos.isEmpty {
                if model.videos.isEmpty {
                    EmptyView(model: model)
                } else {
                    Spacer()
                    ProgressView("Loading ...")
                    Spacer()
                }
            } else {
                List {
                    ForEach(0..<model.videos.count, id: \.self) { index in
                        if model.videos[index].video == nil {
                            LoadingVideoView(model: model, index: index)
                        } else {
                            NavigationLink(value: index) {
                                VideoView(model: model, index: index)
                            }
                        }
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }
            }
            BottomView(model: VideoJoinModel())
            .navigationTitle("Merge Your Videos")
            .navigationDestination(for: Int.self) { index in
                if model.videos[index].video != nil {
                    DetailedView(model: model, index: index)
                }
            }
            .photosPicker(isPresented: $showingPicker, selection: $model.selected,
                          selectionBehavior: PhotosPickerSelectionBehavior.ordered,
                          matching: .videos, photoLibrary: .shared())
            .onChange(of: model.selected) { addVideos() }
            .alert("Error", isPresented: $model.isError) {
                Button("OK", role: .cancel) { model.isError = false }
            } message: {
                Text(model.errMsg).onAppear(perform: {
                    log("\(model.mergeDisplayed)")
                })
            }
            .sheet(isPresented: $model.showMerge, content: {
                MergedView(model: model)
            })
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button(action: showVideoPicker) {
                        Label("Add Video", systemImage: "plus")
                    }
                    
                    Button(action: clearVideos) {
                        Label("Clear Videos", systemImage: "xmark")
                    }.disabled(model.videos.count < 1)
                    
                    Button(action: mergeVideos ) {
                        Label("Merge Videos", systemImage: "figure.walk.motion")
                    }
//                    .disabled(model.videos.count < 2 || !model.allLoaded())

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func mergeVideos() {
//        model.longOp()
        model.merge()
    }
    
    private func clearVideos() {
        model.videos.removeAll()
    }
    
    private func showVideoPicker() {
        showingPicker = true
    }
    
    private func addVideos() {
        model.addVideos()
    }
    
    private func move(indexSet: IndexSet, i: Int) {
        withAnimation {
            model.videos.remove(atOffsets: indexSet)
        }
    }
    
    private func delete(indexSet: IndexSet) {
        withAnimation {
            model.videos.remove(atOffsets: indexSet)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

