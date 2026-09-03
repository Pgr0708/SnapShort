//
//  CleanUpCategoryView.swift
//  SnapShort
//

import SwiftUI
import Photos

// MARK: - Cell Frame Preference Key (for drag-to-select hit testing)

private struct CellFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - View

struct CleanUpCategoryView: View {
    let type: CleanUpCategoryType
    let identifiers: [String]
    @ObservedObject var viewModel: HomeViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var assets: [PHAsset] = []
    @State private var isLoading: Bool = true
    @State private var selectedIds: Set<String> = []
    @State private var cellFrames: [String: CGRect] = [:]
    @State private var showDeleteConfirm: Bool = false
    @State private var selectedForView: PHAsset?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color(hex: "#F5F5F7").ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.2).tint(type.accentColor)
                        Text("Loading \(type.title.lowercased())…")
                            .font(.system(size: 14)).foregroundStyle(Color(hex: "#9CA3AF"))
                    }
                } else if assets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color(hex: "#34C759"))
                        Text("All Clean!")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(hex: "#1C1C1E"))
                        Text("No \(type.title.lowercased()) photos found.")
                            .font(.system(size: 14)).foregroundStyle(Color(hex: "#9CA3AF"))
                    }
                } else {
                    VStack(spacing: 0) {
                        // Description banner
                        HStack(spacing: 10) {
                            Image(systemName: type.icon)
                                .foregroundStyle(type.accentColor)
                            Text(type.description)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "#4B5563"))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(type.accentColor.opacity(0.08))

                        // Drag-hint
                        HStack {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#9CA3AF"))
                            Text("Drag your finger to select multiple photos")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#9CA3AF"))
                            Spacer()
                            Button("Select All") {
                                withAnimation { selectedIds = Set(assets.map(\.localIdentifier)) }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(type.accentColor)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                        // Photo grid
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(assets, id: \.localIdentifier) { asset in
                                    CleanUpCell(
                                        asset: asset,
                                        isSelected: selectedIds.contains(asset.localIdentifier),
                                        accentColor: type.accentColor
                                    )
                                    // Report cell frame for drag hit-testing
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: CellFrameKey.self,
                                                value: [asset.localIdentifier: geo.frame(in: .global)]
                                            )
                                        }
                                    )
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.15)) {
                                            if selectedIds.contains(asset.localIdentifier) {
                                                selectedIds.remove(asset.localIdentifier)
                                            } else {
                                                selectedIds.insert(asset.localIdentifier)
                                                selectedForView = asset
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 100)
                            // Drag-to-select gesture overlaid on grid
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                                    .onChanged { value in
                                        let loc = value.location
                                        for (id, frame) in cellFrames {
                                            if frame.contains(loc) {
                                                withAnimation(.spring(response: 0.1)) {
                                                    selectedIds.insert(id)
                                                }
                                            }
                                        }
                                    }
                            )
                        }
                        // Collect cell frames from preference
                        .onPreferenceChange(CellFrameKey.self) { frames in
                            cellFrames = frames
                        }
                    }
                }

                // Bottom action bar
                if !selectedIds.isEmpty {
                    VStack(spacing: 0) {
                        Divider()
                        HStack(spacing: 16) {
                            Button {
                                withAnimation { selectedIds.removeAll() }
                            } label: {
                                Text("Deselect All")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(hex: "#6B7280"))
                            }

                            Spacer()

                            Text("\(selectedIds.count) selected")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: "#1C1C1E"))

                            Spacer()

                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash.fill")
                                    Text("Delete")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .padding(.bottom, 24)
                        .background(.regularMaterial)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(type.accentColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(assets.count) photos")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
            }
            .task {
                let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                var fetched: [PHAsset] = []
                result.enumerateObjects { a, _, _ in fetched.append(a) }
                assets = fetched
                isLoading = false
            }
            // Apple-native delete confirmation
            .alert("Delete \(selectedIds.count) Photo\(selectedIds.count == 1 ? "" : "s")?",
                   isPresented: $showDeleteConfirm) {
                Button("Delete from Library", role: .destructive) {
                    deleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("These photos will be permanently deleted from your Photos library. This cannot be undone.")
            }
            .fullScreenCover(item: $selectedForView) { asset in
                PhotoDetailView(asset: asset, visionStore: viewModel.visionStore)
            }
        }
    }

    // MARK: - Delete

    private func deleteSelected() {
        let ids = Array(selectedIds)
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var toDelete: [PHAsset] = []
        fetchResult.enumerateObjects { a, _, _ in toDelete.append(a) }

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(toDelete as NSFastEnumeration)
        } completionHandler: { success, error in
            Task { @MainActor in
                if success {
                    let deleted = self.selectedIds
                    withAnimation {
                        self.assets.removeAll { deleted.contains($0.localIdentifier) }
                        self.selectedIds.removeAll()
                    }
                    Task {
                        await self.viewModel.purgeDeletedPhotos(identifiers: Array(deleted))
                    }
                }
            }
        }
    }
}

// MARK: - Cell

private struct CleanUpCell: View {
    let asset: PHAsset
    let isSelected: Bool
    let accentColor: Color

    @State private var thumbnail: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .overlay { ProgressView().scaleEffect(0.6) }
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .overlay(isSelected ? accentColor.opacity(0.25) : Color.clear)
                .overlay(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 0).stroke(accentColor, lineWidth: 3)
                        : nil
                )

                // Checkmark
                ZStack {
                    Circle()
                        .fill(isSelected ? accentColor : Color.white.opacity(0.85))
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
                .padding(5)
                .shadow(radius: 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.spring(response: 0.2), value: isSelected)
        .task(id: asset.localIdentifier) {
            guard thumbnail == nil else { return }
            thumbnail = await loadThumb()
        }
    }

    private func loadThumb() async -> UIImage? {
        await withCheckedContinuation { cont in
            let opts             = PHImageRequestOptions()
            opts.deliveryMode    = .opportunistic
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 120, height: 120),
                contentMode: .aspectFill,
                options: opts
            ) { img, _ in cont.resume(returning: img) }
        }
    }
}
