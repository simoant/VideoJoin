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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @StateObject var model = VideoJoinModel()
    @StateObject var skit = StoreKitManager()
    
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
                    let status = await model.requestAuthorization()
                    if (!status) {
                        model.errMsg = "You need to grant access to the photo library, otherwise the app will not work. Please open Settings->VideoJoin->Photos and set the access level."
                        model.isError = true
                    }
                }
            })
            //  Photo Picker
            .photosPicker(isPresented: $showingPicker, selection: $model.selected,
                          selectionBehavior: PhotosPickerSelectionBehavior.ordered,
                          matching: .videos, photoLibrary: .shared())
            .onChange(of: model.selected) { addVideos() }
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

            //  StoreKit
            .alert("Limited version", isPresented: $model.showPurchaseView ) {
                Button("OK", role: .none) { purchase() }
                Button("Restore purchase", role: .none) { restorePurchase() }
                Button("Cancel", role: .cancel) { cancelPurchase() }
            } message: {
                Text("Current free version serves for evaluation purposes only and allows to merge only \(model.maxFreeVideos) videos at a time. Do you want to buy Full version?")
            }
            .onChange(of: skit.purchased) { purchaseChanged() }
            //  Toolbar
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
                    .disabled(model.videos.count < 2 || !model.allLoaded())

                    EditButton()
                        .disabled(model.videos.count < 1)

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func purchase() {
        Task {
            guard let product = skit.storeProducts.first else {
                log("Product not found");
                await MainActor.run {
                    self.model.selected.removeAll()
                    self.model.errMsg = "Product not found. Pls contact the developer"
                    self.model.isError = true
                }
                return
            }

            try await skit.purchase(product)

            if skit.purchased.count > 0 {
                addVideos()
            } else {
                await MainActor.run {
                    self.model.selected.removeAll()
                    self.model.errMsg = "Sorry, something when wrong, transaction failed."
                    self.model.isError = true
                }
            }
        }
        model.showPurchaseView = false
    }
    
    private func purchaseChanged() {
        log("Purchase changed")
        guard let product = skit.storeProducts.first else { log("Product not found"); return }
        self.model.isPurchased = self.skit.isPurchased(product)
    }

    private func restorePurchase() {
        Task {
            try? await AppStore.sync()
            addVideos()
        }
        model.showPurchaseView = false
    }
    
    private func cancelPurchase() {
        model.selected.removeAll()
        model.showPurchaseView = false
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

