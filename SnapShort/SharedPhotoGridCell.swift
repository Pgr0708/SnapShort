//
//  SharedPhotoGridCell.swift
//  SnapShort
//

import SwiftUI
import Photos

/// Reusable 1:1 photo thumbnail used in both ContentView and CategoryDetailView.
/// - Shows a "⋯" action button in the top-right corner.
/// - In selection mode shows a circular checkmark and responds to tap/drag.
struct SharedPhotoGridCell: View {
    let asset: PHAsset
    @ObservedObject var selectionManager: SelectionManager
    
    let onView: () -> Void
    let onDelete: () -> Void
    let onEditNote: () -> Void
    
    @State private var thumbnail: UIImage?
    @State private var showActions: Bool = false
    
    private var isSelected: Bool { selectionManager.isSelected(asset.localIdentifier) }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay { ProgressView().scaleEffect(0.6) }
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                if selectionManager.isSelecting {
                    withAnimation(.spring(response: 0.2)) {
                        selectionManager.toggle(asset.localIdentifier)
                    }
                } else {
                    onView()
                }
            }
            .overlay(
                // Selection dim overlay
                selectionManager.isSelecting && !isSelected
                    ? Color.black.opacity(0.3)
                    : Color.clear
            )
            
            // Selection mode: circular checkmark in top-left
            if selectionManager.isSelecting {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#4A5FE8") : Color.white.opacity(0.85))
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .shadow(radius: 2)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Normal mode: ⋯ button in top-right
            if !selectionManager.isSelecting {
                Button {
                    showActions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .padding(6)
                .confirmationDialog("", isPresented: $showActions, titleVisibility: .hidden) {
                    Button("View Photo") { onView() }
                    Button("Edit Note") { onEditNote() }
                    Button("Delete Photo", role: .destructive) { onDelete() }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .animation(.spring(response: 0.2), value: isSelected)
        .task(id: asset.localIdentifier) {
            guard thumbnail == nil else { return }
            thumbnail = await loadThumbnail(for: asset)
        }
    }
    
    private func loadThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let scale = UIScreen.main.scale
            let size = CGSize(width: 120 * scale, height: 120 * scale)
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { img, _ in
                continuation.resume(returning: img)
            }
        }
    }
}
