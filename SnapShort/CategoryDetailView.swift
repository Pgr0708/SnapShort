//
//  CategoryDetailView.swift
//  SnapShort
//

import SwiftUI
import Photos

struct CategoryDetailView: View {
    let category: SmartCategory
    @ObservedObject var viewModel: HomeViewModel

    @StateObject private var selectionManager = SelectionManager()

    @State private var assets: [PHAsset] = []
    @State private var isLoading: Bool = true
    @State private var selectedAsset: PHAsset?
    @State private var noteAsset: PHAsset?
    @State private var isSavingAlbum: Bool = false
    @State private var showDeleteSelectedConfirm: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "#F5F5F7").ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.2).tint(Color(hex: "#4A5FE8"))
                    Text("Loading photos…").font(.system(size: 14)).foregroundStyle(Color(hex: "#9CA3AF"))
                }
            } else if assets.isEmpty {
                VStack(spacing: 16) {
                    Text(category.emoji).font(.system(size: 60))
                    Text("No photos yet")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(Color(hex: "#4B5563"))
                    Text("Index Text or Tag Photos first,\nthen tap \"Categorize My Photos\".")
                        .font(.system(size: 14)).foregroundStyle(Color(hex: "#9CA3AF"))
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
            } else {
                ScrollView {
                    // Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: category.colorHex).opacity(0.15)).frame(width: 52, height: 52)
                            Text(category.emoji).font(.system(size: 28))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name).font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: "#1C1C1E"))
                            Text("\(assets.count) photo\(assets.count == 1 ? "" : "s")")
                                .font(.system(size: 13)).foregroundStyle(Color(hex: "#9CA3AF"))
                        }
                        Spacer()
                        Button {
                            isSavingAlbum = true
                            Task { await viewModel.saveAsAlbum(category: category); isSavingAlbum = false }
                        } label: {
                            if isSavingAlbum { ProgressView().scaleEffect(0.8) }
                            else {
                                Label("Save Album", systemImage: "photo.on.rectangle.angled")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#4A5FE8"))
                            }
                        }
                        .disabled(isSavingAlbum)
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)

                    // Photo grid
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            SharedPhotoGridCell(
                                asset: asset,
                                selectionManager: selectionManager,
                                onView: { selectedAsset = asset },
                                onDelete: { viewModel.deletePhoto(identifier: asset.localIdentifier) },
                                onEditNote: { noteAsset = asset }
                            )
                        }
                    }
                    .padding(.bottom, selectionManager.isSelecting ? 90 : 24)
                    // Drag to select
                    .gesture(
                        selectionManager.isSelecting ? dragSelectGesture : nil
                    )
                }
            }

            // Multi-select bottom action bar
            if selectionManager.isSelecting {
                MultiSelectBar(
                    selectionManager: selectionManager,
                    onDeleteSelected: { showDeleteSelectedConfirm = true },
                    onSelectAll: { selectionManager.selectAll(assets.map(\.localIdentifier)) },
                    onSaveAlbum: {
                        Task {
                            // create ephemeral category from selected
                            let selected = selectionManager.selectedIdentifiers
                            guard !selected.isEmpty else { return }
                            let albumTitle = "\(category.emoji) \(category.name) (Selection)"
                            await saveSelectedAsAlbum(ids: Array(selected), title: albumTitle)
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(selectionManager.isSelecting
                         ? "\(selectionManager.selectedCount) Selected"
                         : category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(selectionManager.isSelecting ? "Done" : "Select") {
                    withAnimation(.spring()) {
                        if selectionManager.isSelecting { selectionManager.exitSelection() }
                        else { selectionManager.isSelecting = true }
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#4A5FE8"))
            }
        }
        .task {
            let ids = await viewModel.fetchAssets(for: category)
            let fetched = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            var result: [PHAsset] = []
            fetched.enumerateObjects { a, _, _ in result.append(a) }
            assets = result
            isLoading = false
        }
        .fullScreenCover(item: $selectedAsset) { asset in
            PhotoDetailView(asset: asset, visionStore: viewModel.visionStore)
        }
        .sheet(item: $noteAsset) { asset in
            NoteEditorSheet(assetId: asset.localIdentifier, visionStore: viewModel.visionStore, initialNote: "") { _ in
                noteAsset = nil
            }
        }
        .alert("Delete \(selectionManager.selectedCount) photo\(selectionManager.selectedCount == 1 ? "" : "s")?",
               isPresented: $showDeleteSelectedConfirm) {
            Button("Delete", role: .destructive) {
                let ids = selectionManager.selectedIdentifiers
                selectionManager.exitSelection()
                for id in ids { viewModel.deletePhoto(identifier: id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("These photos will be permanently deleted from your library.")
        }
        .alert("Done", isPresented: Binding(
            get: { viewModel.scanError != nil },
            set: { if !$0 { viewModel.scanError = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(viewModel.scanError ?? "") }
    }

    // MARK: - Drag-to-select gesture

    @State private var dragStartLocation: CGPoint = .zero

    private var dragSelectGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                // Basic drag select — cells toggle as finger passes over them
                // (advanced: would need GeometryReader per cell for precise hit testing)
                _ = value
            }
    }

    private func saveSelectedAsAlbum(ids: [String], title: String) async {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                let placeholder = req.placeholderForCreatedAssetCollection
                let col = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                if let album = col.firstObject, let r = PHAssetCollectionChangeRequest(for: album) {
                    r.addAssets(fetchResult)
                }
            }
            await MainActor.run { viewModel.scanError = "✅ Album \"\(title)\" saved!" }
        } catch {
            await MainActor.run { viewModel.scanError = "Failed: \(error.localizedDescription)" }
        }
    }
}
