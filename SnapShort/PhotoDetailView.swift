//
//  PhotoDetailView.swift
//  SnapShort
//

import SwiftUI
import Photos

struct PhotoDetailView: View {
    let asset: PHAsset
    let visionStore: VisionCacheStore
    @Environment(\.dismiss) private var dismiss
    
    // Zoom & pan
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Swipe-down to dismiss
    @State private var dragOffset: CGSize = .zero
    @GestureState private var isDragging: Bool = false
    
    // UI state
    @State private var fullImage: UIImage?
    @State private var showChrome: Bool = true   // top/bottom bars
    @State private var showInfo: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showNoteEditor: Bool = false
    
    // Notes
    @State private var userNote: String = ""
    @State private var noteSaved: Bool = false
    @FocusState private var noteFieldFocused: Bool
    
    private var dateText: String {
        guard let date = asset.creationDate else { return "Unknown date" }
        let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .short
        return f.string(from: date)
    }
    private var sizeText: String { "\(asset.pixelWidth) × \(asset.pixelHeight)" }
    private var dismissProgress: CGFloat { min(abs(dragOffset.height) / 200, 1.0) }
    
    var body: some View {
        ZStack {
            // Black background (like Photos.app)
            Color.black
                .opacity(1.0 - dismissProgress * 0.5)
                .ignoresSafeArea()
            
            // Main image
            GeometryReader { geo in
                if let fullImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(scale)
                        .offset(x: offset.width, y: offset.height + dragOffset.height)
                        .opacity(1.0 - dismissProgress * 0.3)
                        // Pinch to zoom
                        .gesture(
                            MagnificationGesture()
                                .onChanged { v in scale = max(1, lastScale * v) }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1 { withAnimation { scale = 1; lastScale = 1 } }
                                }
                        )
                        // Double-tap to zoom
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                                else { scale = 2.5; lastScale = 2.5 }
                            }
                        }
                        // Single tap toggles chrome
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { showChrome.toggle() }
                        }
                        // Drag to pan (when zoomed) or swipe-down to dismiss (when normal)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale <= 1 {
                                        // Swipe down to dismiss
                                        if value.translation.height > 0 {
                                            dragOffset = value.translation
                                        }
                                    } else {
                                        // Pan while zoomed
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { value in
                                    if scale <= 1 {
                                        if value.translation.height > 150 {
                                            dismiss()
                                        } else {
                                            withAnimation(.spring()) { dragOffset = .zero }
                                        }
                                    } else {
                                        lastOffset = offset
                                    }
                                }
                        )
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Chrome overlay (top + bottom bars)
            if showChrome {
                VStack {
                    // Top bar — close + share
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        Spacer()
                        // Date
                        if let date = asset.creationDate {
                            Text(date, style: .date)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Info panel (slides up from bottom when showInfo)
                    if showInfo {
                        InfoNotePanel(
                            asset: asset,
                            visionStore: visionStore,
                            userNote: $userNote,
                            noteSaved: $noteSaved,
                            noteFieldFocused: $noteFieldFocused,
                            dateText: dateText,
                            sizeText: sizeText
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Bottom toolbar — like Photos.app
                    HStack(spacing: 0) {
                        // Info / Note
                        ToolbarButton(icon: "info.circle", label: "Info") {
                            withAnimation(.spring(response: 0.4)) { showInfo.toggle() }
                        }
                        
                        // Edit Note
                        ToolbarButton(icon: "note.text.badge.plus", label: "Note") {
                            showNoteEditor = true
                        }
                        
                        // Share
                        ToolbarButton(icon: "square.and.arrow.up", label: "Share") {
                            showShareSheet = true
                        }
                        
                        // Delete
                        ToolbarButton(icon: "trash", label: "Delete", isDestructive: true) {
                            showDeleteConfirm = true
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .padding(.bottom, 30)
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.4), value: showInfo)
        .animation(.easeInOut(duration: 0.2), value: showChrome)
        .task {
            loadFullImage()
            let saved = await visionStore.fetchPhotoNote(for: asset.localIdentifier)
            await MainActor.run { userNote = saved.userNote }
        }
        // Share sheet
        .sheet(isPresented: $showShareSheet) {
            if let fullImage { ShareSheet(items: [fullImage]).ignoresSafeArea() }
        }
        // Inline note editor sheet
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorSheet(
                assetId: asset.localIdentifier,
                visionStore: visionStore,
                initialNote: userNote
            ) { savedNote in
                userNote = savedNote
                showNoteEditor = false
            }
        }
        // Delete confirmation
        .alert("Delete this photo?", isPresented: $showDeleteConfirm) {
            Button("Delete Photo", role: .destructive) {
                deleteAsset()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This photo will be permanently deleted from your library.")
        }
    }
    
    private func loadFullImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        PHImageManager.default().requestImage(
            for: asset, targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit, options: options
        ) { image, _ in
            if let image { DispatchQueue.main.async { self.fullImage = image } }
        }
    }
    
    private func deleteAsset() {
        var assets: [PHAsset] = []
        PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil)
            .enumerateObjects { a, _, _ in assets.append(a) }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }
    }
}

// MARK: - Bottom Toolbar Button

private struct ToolbarButton: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isDestructive ? Color.red : Color.white)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Info + Note Panel (slides up)

private struct InfoNotePanel: View {
    let asset: PHAsset
    let visionStore: VisionCacheStore
    @Binding var userNote: String
    @Binding var noteSaved: Bool
    var noteFieldFocused: FocusState<Bool>.Binding
    let dateText: String
    let sizeText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
            
            // Metadata rows
            InfoRow(icon: "calendar", label: "Date", value: dateText)
            InfoRow(icon: "photo", label: "Resolution", value: sizeText)
            if asset.mediaSubtypes.contains(.photoScreenshot) {
                InfoRow(icon: "iphone", label: "Type", value: "Screenshot")
            }
            if let loc = asset.location {
                InfoRow(icon: "location", label: "Location",
                        value: String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
            }
            
            Divider().background(Color.white.opacity(0.3))
            
            // Notes section
            HStack {
                Image(systemName: "note.text").foregroundStyle(.secondary)
                Text("Notes").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if noteSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11)).foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
            
            ZStack(alignment: .topLeading) {
                if userNote.isEmpty {
                    Text("Add a note…")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(8)
                }
                TextEditor(text: $userNote)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 50, maxHeight: 80)
                    .focused(noteFieldFocused)
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - InfoRow

private struct InfoRow: View {
    let icon: String; let label: String; let value: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(.secondary)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption).foregroundStyle(.primary).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Note Editor Sheet

struct NoteEditorSheet: View {
    let assetId: String
    let visionStore: VisionCacheStore
    let initialNote: String
    let onSave: (String) -> Void
    
    @State private var note: String
    @Environment(\.dismiss) private var dismiss
    
    init(assetId: String, visionStore: VisionCacheStore, initialNote: String, onSave: @escaping (String) -> Void) {
        self.assetId = assetId
        self.visionStore = visionStore
        self.initialNote = initialNote
        self.onSave = onSave
        _note = State(initialValue: initialNote)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#F5F5F7").ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add a description, note, or any keywords you want to search this photo by later.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#6B7280"))
                        .padding(.horizontal, 20)
                    
                    TextEditor(text: $note)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        .frame(minHeight: 150)
                        .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color(hex: "#4A5FE8"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            try? await visionStore.savePhotoNote(assetId: assetId, userNote: note)
                            onSave(note)
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4A5FE8"))
                }
            }
        }
    }
}


// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
