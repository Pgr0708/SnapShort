//
//  CategoryDetailView.swift
//  SnapShort
//

import SwiftUI
import Photos

struct CategoryDetailView: View {
    let category: SmartCategory
    @ObservedObject var viewModel: HomeViewModel

    @Environment(\.dismiss) private var dismiss
    @StateObject private var selectionManager = SelectionManager()

    @State private var assets: [PHAsset] = []
    @State private var isLoading: Bool = true
    @State private var selectedAsset: PHAsset?
    @State private var noteAsset: PHAsset?
    @State private var isSavingAlbum: Bool = false
    @State private var isAlbumSavedInPhotos: Bool = false
    @State private var showDeleteSelectedConfirm: Bool = false
    @State private var showDeleteAllConfirm: Bool = false
    @State private var cellFrames: [String: CGRect] = [:]

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "#F5F5F7").ignoresSafeArea()

            if isLoading {
                loadingView
            } else if assets.isEmpty {
                emptyView
            } else {
                contentScrollView
            }

            // Multi-select bottom action bar
            if selectionManager.isSelecting {
                MultiSelectBar(
                    selectionManager: selectionManager,
                    onDeleteSelected: { showDeleteSelectedConfirm = true },
                    onSelectAll: handleSelectAll,
                    onSaveAlbum: handleSaveSelectionAsAlbum
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(selectionManager.isSelecting ? "Done" : "Select") {
                    withAnimation {
                        if selectionManager.isSelecting { selectionManager.exitSelection() }
                        else { selectionManager.isSelecting = true }
                    }
                }
            }
        }
        .task {
            let ids = await viewModel.fetchAssets(for: category)
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            var fetched: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in fetched.append(asset) }
            assets = fetched
            checkAlbumSavedState()
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
                let ids = Array(selectionManager.selectedIdentifiers)
                selectionManager.exitSelection()
                deleteAssets(ids: ids)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("These photos will be permanently deleted from your library.")
        }
        .alert("Delete All \(assets.count) Photos in \"\(category.name)\"?",
               isPresented: $showDeleteAllConfirm) {
            Button("Delete from Library", role: .destructive) {
                let ids = assets.map(\.localIdentifier)
                deleteAssets(ids: ids)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("These \(assets.count) photos will be permanently deleted from your Photos library and removed across all tabs.")
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2).tint(Color(hex: "#4A5FE8"))
            Text("Loading photos…")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#9CA3AF"))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Text(category.emoji).font(.system(size: 60))
            Text("No photos")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: "#4B5563"))
            Text("No photos found in this category.")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#9CA3AF"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var contentScrollView: some View {
        ScrollView {
            headerView
            photoGridView
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            if let uiImage = UIImage(named: "cat_\(category.id)") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: category.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .shadow(color: category.gradientColors.first?.opacity(0.35) ?? .clear, radius: 6, y: 3)
                    Text(category.emoji)
                        .font(.system(size: 28))
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#1C1C1E"))
                Text("\(assets.count) photo\(assets.count == 1 ? "" : "s")")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }
            
            Spacer()
            
            saveAlbumButton
            
            Button(role: .destructive) {
                showDeleteAllConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 32, height: 32)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var saveAlbumButton: some View {
        Button {
            isSavingAlbum = true
            Task {
                await viewModel.saveAsAlbum(category: category)
                isSavingAlbum = false
                checkAlbumSavedState()
            }
        } label: {
            if isSavingAlbum {
                ProgressView().scaleEffect(0.8)
            } else if isAlbumSavedInPhotos {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("In Photos")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "#34C759"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#34C759").opacity(0.12))
                .clipShape(Capsule())
            } else {
                Label("Save Album", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4A5FE8"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#4A5FE8").opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .disabled(isSavingAlbum)
    }

    private var photoGridView: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(assets, id: \.localIdentifier) { asset in
                SharedPhotoGridCell(
                    asset: asset,
                    selectionManager: selectionManager,
                    onView: { selectedAsset = asset },
                    onDelete: {
                        viewModel.deletePhoto(identifier: asset.localIdentifier)
                        withAnimation {
                            assets.removeAll { $0.localIdentifier == asset.localIdentifier }
                        }
                    },
                    onEditNote: { noteAsset = asset }
                )
            }
        }
        .padding(.bottom, selectionManager.isSelecting ? 90 : 24)
        .onPreferenceChange(PhotoCellFrameKey.self) { frames in
            self.cellFrames = frames
        }
        .simultaneousGesture(
            selectionManager.isSelecting ? dragSelectGesture : nil
        )
    }

    // MARK: - Helpers

    private func checkAlbumSavedState() {
        let albumTitle = "\(category.emoji) \(category.name)"
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title == %@", albumTitle)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
        isAlbumSavedInPhotos = collections.count > 0
    }

    private func handleSelectAll() {
        selectionManager.selectAll(assets.map(\.localIdentifier))
    }

    private func handleSaveSelectionAsAlbum() {
        let selected = Array(selectionManager.selectedIdentifiers)
        guard !selected.isEmpty else { return }
        let albumTitle = "\(category.emoji) \(category.name) (Selection)"
        Task {
            await saveSelectedAsAlbum(ids: selected, title: albumTitle)
        }
    }

    private func deleteAssets(ids: [String]) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var toDelete: [PHAsset] = []
        fetchResult.enumerateObjects { a, _, _ in toDelete.append(a) }

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(toDelete as NSFastEnumeration)
        } completionHandler: { success, error in
            Task { @MainActor in
                if success {
                    let idSet = Set(ids)
                    withAnimation {
                        self.assets.removeAll { idSet.contains($0.localIdentifier) }
                    }
                    await viewModel.purgeDeletedPhotos(identifiers: ids)
                } else if let error {
                    viewModel.scanError = "Delete failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private var dragSelectGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                let loc = value.location
                for (id, frame) in cellFrames {
                    if frame.contains(loc) {
                        if !selectionManager.isSelected(id) {
                            selectionManager.select(id)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
            }
    }

    private func saveSelectedAsAlbum(ids: [String], title: String) async {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let createReq = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                let placeholder = createReq.placeholderForCreatedAssetCollection
                let albumFetch = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [placeholder.localIdentifier], options: nil
                )
                if let newAlbum = albumFetch.firstObject,
                   let req = PHAssetCollectionChangeRequest(for: newAlbum) {
                    req.addAssets(fetchResult)
                }
            }
            await MainActor.run {
                viewModel.scanError = "✅ Selection saved as album \"\(title)\"!"
                selectionManager.exitSelection()
            }
        } catch {
            await MainActor.run {
                viewModel.scanError = "Failed: \(error.localizedDescription)"
            }
        }
    }
}
