//
//  ContentView.swift
//  SnapShort
//

import SwiftUI
import Photos
import PhotosUI

struct ContentView: View {
    @EnvironmentObject private var settings: SettingsManager
    @StateObject private var viewModel: HomeViewModel
    @StateObject private var photoLibrary = PhotoLibraryManager()
    @StateObject private var speech = SpeechRecognizer()
    @StateObject private var selectionManager = SelectionManager()
    
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var showSaveAlert: Bool = false
    @State private var customFileName: String = ""
    @State private var showSettings = false
    @State private var selectedAsset: PHAsset?
    @State private var noteAsset: PHAsset?
    @State private var showDeleteSelectedConfirm: Bool = false
    
    private let spacing: CGFloat = 5
    
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing)
        ]
    }
    
    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // MARK: Header
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppInfo.appName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color(hex: "#000D5F"))
                            if let assets = photoLibrary.assets {
                                Text("\(assets.count) photos")
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: "#757686"))
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            // Future: notifications
                        } label: {
                            Image(systemName: "bell")
                                .foregroundStyle(Color(hex: "#1A1A2E"))
                                .frame(width: 40, height: 40)
                                .background(Color(hex: "#F5F5F7"))
                                .clipShape(.circle)
                        }
                        
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(Color(hex: "#1A1A2E"))
                                .frame(width: 40, height: 40)
                                .background(Color(hex: "#F5F5F7"))
                                .clipShape(.circle)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                    
                    // MARK: Search Bar
                    HStack(spacing: 16) {
                        if !viewModel.searchQuery.isEmpty {
                            Button {
                                viewModel.clearSearch()
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(Color(hex: "#757686"))
                            }
                        } else {
                            Button {
                                if speech.isRecording {
                                    speech.stopRecording()
                                    // Auto-search when recording stops with a non-empty transcript
                                    if !viewModel.searchQuery.isEmpty {
                                        viewModel.performSearch()
                                    }
                                } else {
                                    speech.startRecording()
                                }
                            } label: {
                                ZStack {
                                    if speech.isRecording {
                                        Circle()
                                            .fill(Color.red.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                            .scaleEffect(speech.isRecording ? 1.3 : 1.0)
                                            .animation(
                                                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                                value: speech.isRecording
                                            )
                                    }
                                    Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(speech.isRecording ? .red : Color(hex: "#4A5FE8"))
                                }
                            }
                            .alert("Microphone Access Denied", isPresented: $speech.permissionDenied) {
                                Button("Open Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("Please allow microphone and speech recognition access in Settings to use voice search.")
                            }
                        }
                        
                        TextField(viewModel.searchMode.placeholder, text: $viewModel.searchQuery)
                            .font(.system(size: 18))
                            .textFieldStyle(.plain)
                            .submitLabel(.search)
                            .onSubmit {
                                viewModel.performSearch()
                            }
                        
                        if !viewModel.searchQuery.isEmpty {
                            Button {
                                viewModel.performSearch()
                            } label: {
                                Text("Search")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#4A5FE8"))
                            }
                        } else {
                            // Photo picker upload button
                            if let image = pickedImage {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    
                                    Button {
                                        pickedImage = nil
                                        selectedPickerItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                            .background(Color.black.clipShape(Circle()))
                                    }
                                    .offset(x: 4, y: -4)
                                }
                                .onTapGesture {
                                    showSaveAlert = true
                                }
                            } else {
                                PhotosPicker(selection: $selectedPickerItem, matching: .images) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundStyle(Color(hex: "#4A5FE8"))
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onChange(of: selectedPickerItem) { _, newItem in
                                    Task {
                                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                                           let uiImage = UIImage(data: data) {
                                            await MainActor.run {
                                                self.pickedImage = uiImage
                                                self.customFileName = "Photo_\(Int(Date().timeIntervalSince1970))"
                                                // Show save dialog as soon as image is picked
                                                self.showSaveAlert = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.white)
                    )
                    .padding(.horizontal, 24)
                    .shadow(color: .black.opacity(0.06), radius: 15, y: 5)
                    .onChange(of: speech.transcript) { _, newValue in
                        // Sync live speech transcript into the search field in real-time
                        if !newValue.isEmpty {
                            viewModel.searchQuery = newValue
                        }
                    }
                    
                    // Live recording indicator
                    if speech.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 7, height: 7)
                                .opacity(speech.isRecording ? 1 : 0)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: speech.isRecording)
                            Text("Listening… tap mic to stop & search")
                                .font(.caption)
                                .foregroundStyle(Color.red.opacity(0.8))
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 4)
                        .transition(.opacity)
                    }
                    
                    // MARK: Search Mode Toggle
                    HStack(spacing: 0) {
                        ForEach(SearchMode.allCases, id: \.self) { mode in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.searchMode = mode
                                    viewModel.clearSearch()
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(mode.rawValue)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(viewModel.searchMode == mode ? .white : Color(hex: "#6B7280"))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    viewModel.searchMode == mode
                                        ? (mode == .textInImage ? Color(hex: "#4A5FE8") : Color(hex: "#0A9396"))
                                        : Color.clear
                                )
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(3)
                    .background(Color(hex: "#F0F2F5"))
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    
                    // MARK: Action Buttons Row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ActionButton(
                                title: "Find Duplicates",
                                icon: "doc.on.doc",
                                color: Color(hex: "#4A5FE8")
                            ) {
                                viewModel.promptDuplicateScan()
                            }
                            
                            // Context-aware index button based on search mode
                            if viewModel.searchMode == .textInImage {
                                ActionButton(
                                    title: "Index Text",
                                    icon: "text.magnifyingglass",
                                    color: Color(hex: "#0A9396")
                                ) {
                                    viewModel.startOCRIndexing()
                                }
                            } else {
                                ActionButton(
                                    title: "Tag Photos",
                                    icon: "photo.on.rectangle.angled",
                                    color: Color(hex: "#0A9396")
                                ) {
                                    viewModel.startContentTagIndexing()
                                }
                            }
                            
                            ActionButton(
                                title: "Search Text",
                                icon: "doc.text.magnifyingglass",
                                color: Color(hex: "#5C6BC0")
                            ) {
                                // Focus on the search bar
                                if viewModel.searchQuery.isEmpty {
                                    viewModel.searchQuery = " "
                                    viewModel.searchQuery = ""
                                }
                            }
                            
                            ActionButton(
                                title: "Screenshots",
                                icon: "iphone",
                                color: Color(hex: "#E67E22")
                            ) {
                                filterScreenshots()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    
                    // MARK: Main Content
                    if viewModel.activeSearch {
                        searchResultsView
                    } else {
                        photoGridView
                    }
                }
                
                // MARK: Progress Overlay
                if viewModel.isScanning, let progress = viewModel.scanProgress {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "gearshape.2")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(progress.isScanning ? 360 : 0))
                            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: progress.isScanning)
                        
                        Text(viewModel.scanServiceName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        ProgressView(value: progress.fractionCompleted)
                            .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#4A5FE8")))
                            .frame(width: 220)
                        
                        Text("\(progress.processedCount) / \(progress.totalCount) photos")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        if progress.estimatedSecondsRemaining > 0 {
                            Text("~\(Int(progress.estimatedSecondsRemaining))s remaining")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Button("Cancel") {
                            viewModel.cancelScan()
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(hex: "#FF6B6B"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(hex: "#1A1A2E").opacity(0.95))
                    )
                }
            }
            .background(Color(hex: "#FAFAFA"))
            .onAppear {
                settings.requestPhotosPermission()
            }
            .onChange(of: settings.hasPhotosAccess, initial: true) { _, hasAccess in
                if hasAccess { photoLibrary.fetchPhotos() }
            }
            // MARK: Save Alert
            .alert("Save Image", isPresented: $showSaveAlert) {
                TextField("File name", text: $customFileName)
                
                Button("Save to Camera Roll") {
                    if let pickedImage {
                        HelperFunctions.saveToPhotoLibrary(image: pickedImage)
                    }
                    clearPickedImage()
                }
                
                Button("Save to Documents") {
                    if let pickedImage {
                        HelperFunctions.saveToDocuments(image: pickedImage, name: customFileName)
                    }
                    clearPickedImage()
                }
                
                Button("Cancel", role: .cancel) {
                    clearPickedImage()
                }
            } message: {
                Text("Choose where to save this image.")
            }
            // MARK: Sensitivity Picker Sheet
            .sheet(isPresented: $viewModel.showSensitivityPicker) {
                SensitivityPickerSheet(viewModel: viewModel)
                    .presentationDetents([.fraction(0.45)])
                    .presentationDragIndicator(.visible)
            }
            // MARK: Duplicate Results Sheet
            .sheet(isPresented: $viewModel.showDuplicateResults) {
                DuplicateResultsView(viewModel: viewModel)
            }
            // MARK: Photo Detail (full-screen, like Photos.app)
            .fullScreenCover(item: $selectedAsset) { asset in
                PhotoDetailView(asset: asset, visionStore: viewModel.visionStore)
            }
            // MARK: Note Editor
            .sheet(item: $noteAsset) { asset in
                NoteEditorSheet(assetId: asset.localIdentifier, visionStore: viewModel.visionStore, initialNote: "") { _ in
                    noteAsset = nil
                }
            }
            // MARK: Delete selected confirmation
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
            // MARK: Settings Sheet
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // MARK: Scan Result Alert
            .alert("Done", isPresented: Binding(
                get: { viewModel.scanError != nil },
                set: { if !$0 { viewModel.scanError = nil } }
            )) {
                Button("OK") { viewModel.scanError = nil }
            } message: {
                Text(viewModel.scanError ?? "")
            }
        }
    }
    
    // MARK: - Photo Grid
    
    private var photoGridView: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical) {
                if let assets = photoLibrary.assets {
                    // Select button row
                    HStack {
                        Spacer()
                        Button(selectionManager.isSelecting ? "Done" : "Select") {
                            withAnimation(.spring()) {
                                if selectionManager.isSelecting { selectionManager.exitSelection() }
                                else { selectionManager.isSelecting = true }
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#4A5FE8"))
                        .padding(.trailing, 16)
                        .padding(.vertical, 6)
                    }
                    
                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(0..<assets.count, id: \.self) { index in
                            let asset = assets.object(at: index)
                            SharedPhotoGridCell(
                                asset: asset,
                                selectionManager: selectionManager,
                                onView: { selectedAsset = asset },
                                onDelete: { viewModel.deletePhoto(identifier: asset.localIdentifier) },
                                onEditNote: { noteAsset = asset }
                            )
                        }
                    }
                    .padding(.horizontal, spacing)
                    .padding(.bottom, selectionManager.isSelecting ? 90 : 16)
                } else {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5)
                        Text("Loading photos...")
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "#757686"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                }
            }
            
            // Multi-select bottom bar
            if selectionManager.isSelecting {
                MultiSelectBar(
                    selectionManager: selectionManager,
                    onDeleteSelected: { showDeleteSelectedConfirm = true },
                    onSelectAll: {
                        if let assets = photoLibrary.assets {
                            var ids: [String] = []
                            assets.enumerateObjects { a, _, _ in ids.append(a.localIdentifier) }
                            selectionManager.selectAll(ids)
                        }
                    },
                    onSaveAlbum: {
                        Task {
                            let ids = Array(selectionManager.selectedIdentifiers)
                            guard !ids.isEmpty else { return }
                            let title = "SnapShort Selection"
                            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                            try? await PHPhotoLibrary.shared().performChanges {
                                let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                                let ph = req.placeholderForCreatedAssetCollection
                                let col = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [ph.localIdentifier], options: nil)
                                if let album = col.firstObject, let r = PHAssetCollectionChangeRequest(for: album) { r.addAssets(fetchResult) }
                            }
                            selectionManager.exitSelection()
                            viewModel.scanError = "✅ Album saved to Photos!"
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: selectionManager.isSelecting)
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        VStack(spacing: 0) {
            if viewModel.isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Searching...")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#757686"))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "#C4C6D6"))
                    Text("No results found")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#757686"))
                    Text("Try \"Index Text\" first, then search for words inside your screenshots.")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#757686").opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button {
                        viewModel.startOCRIndexing()
                        viewModel.clearSearch()
                    } label: {
                        Label("Index Text Now", systemImage: "text.magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#0A9396"))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 60)
            } else {
                Text("\(viewModel.searchResults.count) results")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#757686"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                
                List(viewModel.searchResults) { result in
                    SearchResultRow(result: result) {
                        let fetch = PHAsset.fetchAssets(
                            withLocalIdentifiers: [result.assetLocalIdentifier],
                            options: nil
                        )
                        if let asset = fetch.firstObject { selectedAsset = asset }
                    } onDelete: {
                        viewModel.deletePhoto(identifier: result.assetLocalIdentifier)
                    } onEditNote: {
                        let fetch = PHAsset.fetchAssets(
                            withLocalIdentifiers: [result.assetLocalIdentifier],
                            options: nil
                        )
                        if let asset = fetch.firstObject { noteAsset = asset }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func clearPickedImage() {
        pickedImage = nil
        selectedPickerItem = nil
    }
    
    private func filterScreenshots() {
        // Re-fetch with screenshot filter
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaSubtype == %ld",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        photoLibrary.setAssets(result)
    }
}

// MARK: - PHAsset Identifiable

extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(color)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sensitivity Picker Sheet

struct SensitivityPickerSheet: View {
    @ObservedObject var viewModel: HomeViewModel
    
    private let options: [(DuplicateSensitivity, String, String, Color)] = [
        (.strict,     "Strict",     "Only exact/near-exact duplicates",        Color(hex: "#27AE60")),
        (.balanced,   "Balanced",   "Similar photos with minor differences",   Color(hex: "#4A5FE8")),
        (.aggressive, "Aggressive", "Broadly similar — may include false hits", Color(hex: "#E74C3C"))
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Duplicate Sensitivity")
                .font(.title3.bold())
                .padding(.horizontal, 24)
                .padding(.top, 24)
            
            VStack(spacing: 10) {
                ForEach(options, id: \.0.threshold) { (sensitivity, name, desc, color) in
                    Button {
                        viewModel.startDuplicateScan(sensitivity: sensitivity)
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(color)
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#1A1A2E"))
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: "#757686"))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#C4C6D6"))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            
            Button("Cancel") {
                viewModel.showSensitivityPicker = false
            }
            .font(.system(size: 14))
            .foregroundStyle(Color(hex: "#757686"))
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResultItem
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?
    var onEditNote: (() -> Void)?
    @State private var thumbnail: UIImage?
    @State private var showActions: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay(ProgressView().scaleEffect(0.6))
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .foregroundStyle(Color(hex: "#1A1A2E"))
                
                HStack(spacing: 4) {
                    Image(systemName: result.source == .ocr ? "text.alignleft" : "tag")
                        .font(.caption2)
                    Text(result.source == .ocr ? "OCR Match" : "Tag Match")
                        .font(.caption)
                }
                .foregroundStyle(Color(hex: "#757686"))
            }
            
            Spacer()
            
            // ⋯ action button
            Button {
                showActions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#9CA3AF"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "#F3F4F6"))
                    .clipShape(Circle())
            }
            .confirmationDialog("", isPresented: $showActions, titleVisibility: .hidden) {
                Button("View Photo") { onTap?() }
                Button("Edit Note") { onEditNote?() }
                Button("Delete Photo", role: .destructive) { onDelete?() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .task(id: result.assetLocalIdentifier) { loadThumbnail() }
    }
    
    private func loadThumbnail() {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [result.assetLocalIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 120, height: 120),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image { DispatchQueue.main.async { self.thumbnail = image } }
        }
    }
}

// MARK: - Duplicate Results View

struct DuplicateResultsView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.duplicateClusters.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                        Text("All Clean!")
                            .font(.title2.bold())
                        Text("All duplicate clusters have been resolved.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        Section {
                            Text("\(viewModel.duplicateClusters.count) clusters found — \(viewModel.duplicateClusters.reduce(0) { $0 + $1.assetIdentifiers.count - 1 }) photos can be removed")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                        }
                        
                        ForEach(viewModel.duplicateClusters) { cluster in
                            DuplicateClusterRow(cluster: cluster, viewModel: viewModel)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Duplicates Found")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.duplicateClusters.isEmpty {
                        Text("\(viewModel.duplicateClusters.count) clusters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct DuplicateClusterRow: View {
    let cluster: DuplicateCluster
    @ObservedObject var viewModel: HomeViewModel
    @State private var showDeleteConfirm = false
    
    var duplicateCount: Int { cluster.assetIdentifiers.count - 1 }
    
    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cluster.assetIdentifiers, id: \.self) { id in
                        DuplicateThumbnail(
                            identifier: id,
                            isRecommended: id == cluster.recommendedKeepIdentifier
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            
            HStack {
                Label("Keep best • delete \(duplicateCount)", systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete \(duplicateCount)", systemImage: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog(
            "Delete \(duplicateCount) duplicate\(duplicateCount == 1 ? "" : "s")?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.deleteDuplicates(in: cluster)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The recommended best-quality photo will be kept. This cannot be undone.")
        }
    }
}

struct DuplicateThumbnail: View {
    let identifier: String
    let isRecommended: Bool
    @State private var image: UIImage?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView().scaleEffect(0.6))
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isRecommended ? Color.green : Color.clear, lineWidth: 3)
            )
            
            if isRecommended {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
                    .background(Color.white.clipShape(Circle()))
                    .offset(x: 6, y: -6)
            } else {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red.opacity(0.7))
                    .background(Color.white.clipShape(Circle()))
                    .offset(x: 6, y: -6)
            }
        }
        .task(id: identifier) { loadImage() }
    }
    
    private func loadImage() {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let first = fetchResult.firstObject else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: first, targetSize: CGSize(width: 176, height: 176),
            contentMode: .aspectFill, options: options
        ) { img, _ in
            if let img { DispatchQueue.main.async { self.image = img } }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Accent Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(AppAccentColor.allCases) { accent in
                            Button {
                                settings.selectedAccentColor = accent.rawValue
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(accent.color)
                                        .frame(width: 36, height: 36)
                                    if settings.selectedAccentColor == accent.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Photo Access") {
                    HStack {
                        Label("Photos Permission", systemImage: "photo.on.rectangle")
                        Spacer()
                        Text(settings.hasPhotosAccess ? "Granted" : "Denied")
                            .foregroundStyle(settings.hasPhotosAccess ? .green : .red)
                            .font(.subheadline)
                    }
                    
                    if !settings.hasPhotosAccess {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text(AppInfo.appName).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AppInfo.version).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(.gray.opacity(0.18))
                        .overlay {
                            ProgressView().scaleEffect(0.6)
                        }
                }
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .task(id: asset.localIdentifier) {
            loadImage()
        }
    }
    
    private func loadImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: 120 * scale, height: 120 * scale)
        PHImageManager.default().requestImage(
            for: asset, targetSize: targetSize,
            contentMode: .aspectFill, options: options
        ) { fetchedImage, _ in
            if let fetchedImage {
                DispatchQueue.main.async { self.image = fetchedImage }
            }
        }
    }
}
