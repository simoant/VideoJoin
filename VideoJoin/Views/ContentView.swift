//
//  ContentView.swift
//  VideoJoin
//
//  Created by Anton Simonov on 23/3/24.
//

import SwiftUI
import PhotosUI
import SwiftData
import StoreKit
import RevenueCatUI
import RevenueCat

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @StateObject var model = VideoJoinModel()
    
    @State private var showingPicker = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if model.videos.isEmpty {
                    if model.selected.isEmpty {
                        EmptyView(model: model)
                    } else {
                        Spacer()
                        ProgressView("Loading ...")
                        Spacer()
                    }
                } 
//                else {
                List {
                    ForEach(0..<model.videos.count, id: \.self) { index in
                        if model.videos[index].isValid {
                            if model.videos[index].video == nil {
                                LoadingVideoView(model: model, index: index)
                            } else {
                                NavigationLink(value: index) {
                                    VideoView(model: model, index: index)
                                }
                            }
                        }
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
//                }
                }
                Spacer()
                BottomView(model: VideoJoinModel())
            }
            .navigationTitle("Merge Your Videos")
            .navigationDestination(for: Int.self) { index in
                if model.videos[index].video != nil {
                    DetailedView(model: model, index: index)
                }
            }
            .onAppear(perform: {
                clearTemporaryFiles()
                Task {
                    Task { await model.updateVersionStatus() }
                    let status = await model.requestAuthorization()
                    if (!status) {
                        model.errMsg = "You need to grant access to the photo library, otherwise the app will not work. Please open Settings->VideoJoin->Photos and set the access level."
                        model.isError = true
                    }
                }
            })
            .sheet(isPresented: $model.showPaywall) {
//                PaywallView(configuration: paywallConfig)
                RevenueCatPaywallView(model: model)
            }
            //  Photo Picker
            .photosPicker(isPresented: $showingPicker, selection: $model.selected,
                          selectionBehavior: PhotosPickerSelectionBehavior.ordered,
                          matching: .videos, photoLibrary: .shared())
            .onChange(of: model.selected) {
                log("onChange selected: \(model.selected)")
                addVideos()
            }
            //  Error
            .alert("Error", isPresented: $model.isError) {
                Button("OK", role: .cancel) { model.isError = false }
            } message: {
                Text(model.errMsg)
            }
            //  Merge View
            .sheet(isPresented: $model.showMergeView, content: {
                MergedView(model: model)
            })

            //  Toolbar
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    EditButton()
                        .disabled(model.videos.count < 1)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: showVideoPicker) {
                        Label("Add Video", systemImage: "plus")
                    }
                    
                    Button(action: clearVideos) {
                        Label("Clear Videos", systemImage: "xmark")
                    }.disabled(model.videos.count < 1)
                    
                    Button(action: mergeVideos ) {
                        Label("Merge Videos", systemImage: "figure.walk.motion")
                    }
                    .disabled(model.videos.count < 2 || !model.allLoaded())


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


struct RevenueCatPaywallView: View {
    @StateObject var model: VideoJoinModel

    var body: some View {
        PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { customerInfo in
                log("Purchase completed: \(customerInfo.entitlements)")
                Task { await model.updateVersionStatus() }
                //                        addVideos()
            }
            .onPurchaseFailure { error in
                log("Purchase failed: \(error.localizedDescription)")
                model.errMsg = "Something went wrong with your purchase"
                model.isError = true
            }
            .onPurchaseCancelled {
                log("Purchase cancelled")
                model.errMsg = "Your purchase was canceled. You are still using limited version"
                model.isError = true
            }
            .onRestoreCompleted { customerInfo in
                print("Restore completed")
                Task { await model.updateVersionStatus() }
                //                        addVideos()
            }
            .onRestoreFailure {_ in
                log("Restore failed")
                model.errMsg = "Could not restore purchases. You are still using limited version"
                model.isError = true
            }
    }
}
